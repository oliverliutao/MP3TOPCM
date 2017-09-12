//
//  ViewController.m
//  MP3TOPCM
//
//  Created by TAO LIU on 11/9/17.
//  Copyright © 2017 MOZAT. All rights reserved.
//

#import "ViewController.h"
#import "AudioFileConvertOperation.h"
#import "AVAudioPlayer+PCM.h"

#define AUDIO_CACHE_FOLDER ([NSString stringWithFormat:@"%@/audio",[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject]])



@interface ViewController ()<AudioFileConvertOperationDelegate,AVAudioPlayerDelegate>

@property (nonatomic, strong) NSURL *sourceURL;

@property (nonatomic, strong) NSURL *destinationURL;

@property (assign, nonatomic) AudioFormatID outputFormat;

@property (assign, nonatomic) Float64 sampleRate;

@property (nonatomic, strong) AudioFileConvertOperation *operation;

@property (nonatomic, strong) AVAudioPlayer *player;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

-(void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    
//    NSString *_path = [[NSBundle mainBundle] pathForResource:@"drum_4_4" ofType:@"mp3"];
//    NSURL *sourceURL = [NSURL fileURLWithPath:_path];
//    
//    NSString *destination = [ViewController getCachesUrlPath];
//    NSString *filePath = [NSString stringWithFormat:@"%@/drum_4_4.pcm",destination];
//    NSURL *destURL = [NSURL URLWithString:filePath];
//    
//    
//    [self startConvertSource:sourceURL DestinationURL:destURL];
    
    NSString *sourcePath = [[NSBundle mainBundle] pathForResource:@"drum_4_4" ofType:@"mp3"];
    self.sourceURL = [NSURL fileURLWithPath:sourcePath];
    
    // Set the default values.
    self.outputFormat = kAudioFormatLinearPCM;
    self.sampleRate = 44100;
    
    NSString *destination = [ViewController getCachesUrlPath];
    NSString *filePath = [NSString stringWithFormat:@"%@/drum_4_4.pcm",destination];
    NSURL *destURL = [NSURL URLWithString:filePath];
    self.destinationURL = destURL;
    
    self.operation = [[AudioFileConvertOperation alloc] initWithSourceURL:self.sourceURL destinationURL:self.destinationURL sampleRate:self.sampleRate outputFormat:self.outputFormat];
    
    self.operation.delegate = self;
    
    __weak __typeof__(self) weakSelf = self;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [weakSelf.operation start];
    });

}

+(NSString *)getCachesUrlPath{
    NSString *strDic = nil;
    strDic = AUDIO_CACHE_FOLDER;
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:strDic]) {
        
        [[NSFileManager defaultManager] createDirectoryAtPath:strDic withIntermediateDirectories:YES attributes:nil error:nil];
        
    }
    
    return strDic;
    
}

-(void)startConvertSource:(NSURL*)sourceURL DestinationURL:(NSURL*)destinationURL {
    
    AudioFormatID outputFormat = kAudioFormatLinearPCM;
    
    char formatID[5];
    *(UInt32 *)formatID = CFSwapInt32HostToBig(outputFormat);
    NSString *formatString = [[NSString stringWithFormat:@"%4.4s", formatID] uppercaseString];
    
    NSArray  *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *destinationFilePath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"Output%@", formatString]];
    
    destinationURL = [NSURL fileURLWithPath:destinationFilePath];
    
    
    AudioFileConvertOperation *operation = [[AudioFileConvertOperation alloc] initWithSourceURL:sourceURL destinationURL:destinationURL sampleRate:44100 outputFormat:outputFormat];
    
    operation.delegate = self;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [operation start];
    });
}


#pragma mark ---- AudioFileConvertOperationDelegate
- (void)audioFileConvertOperation:(AudioFileConvertOperation *)audioFileConvertOperation didEncounterError:(NSError *)error {
    
    NSLog(@"convert error");
    
}

- (void)audioFileConvertOperation:(AudioFileConvertOperation *)audioFileConvertOperation didCompleteWithURL:(NSURL *)destinationURL {
    
    NSLog(@"convert complete destinationURL=%@",destinationURL);
    
#warning mark ---- method 1
    NSData *pcmData = [NSData dataWithContentsOfFile:[destinationURL absoluteString]];
    
    NSError *error = nil;
    
    AudioStreamBasicDescription format;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mSampleRate = 44100;
    
    format.mBitsPerChannel = 16;
    format.mChannelsPerFrame = 1;
    format.mBytesPerFrame = format.mChannelsPerFrame * (format.mBitsPerChannel / 8);
    
    format.mFramesPerPacket = 1;
    format.mBytesPerPacket = format.mFramesPerPacket * format.mBytesPerFrame;
    
    format.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    
    
    self.player = [[AVAudioPlayer alloc] initWithPcmData:pcmData pcmFormat:format error:&error];
    self.player.numberOfLoops = -1;
    
    [self.player play];
    
#warning mark ---- method 2
//    NSError *error = nil;
//    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:destinationURL error:&error];
//    self.player.delegate = self;
//    [self.player play];
    
    
}


// MARK: AVAudioPlayerDelegate Protocol Methods.

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Playback Error" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alertController animated:YES completion:nil];
    
    [self audioPlayerDidFinishPlaying:player successfully:NO];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    
    self.player = nil;

}

// MARK: Notification Handler Methods.

- (void)handleAudioSessionInterruptionNotification:(NSNotification *)notification {
    
    // For the purposes of this sample we only stop playback if needed and reset the UI back to being ready to convert again.
    if (self.player != nil) {
        [self.player stop];
        [self audioPlayerDidFinishPlaying:self.player successfully:YES];
    }
    
}


@end
