//
//  MediaInfoImporter.mm
//
//  Queries dynamic library MediaInfo for some metadata attributes
//  and makes them availabe for Spotlight.
//
//  Created by Sebastian Heltewig on 08.08.12.
//

#include "MediaInfoImporter.h"
#include <MediaInfoDLL_Static.h>

using namespace MediaInfoDLL;

// -----------------------------------------------------------------------------
// General Utility Functions
// -----------------------------------------------------------------------------

int STR2INT_SUCCESS = 0;
int STR2INT_OVERFLOW = 1;
int STR2INT_UNDERFLOW = 2;
int STR2INT_INCONVERTIBLE = 3;

/* 
 * Converts a given C-String (char*) to an integer, saves the result to the
 * given parameter i and signals succes (or error) via return value.
 * It is only safe to use i if STR2INT_SUCCESS is returned.
 */
int str2int (int &i, char const *s, int base = 0)
{
    char *end;
    long  l;
    errno = 0;
    l = strtol(s, &end, base);
    if ((errno == ERANGE && l == LONG_MAX) || l > INT_MAX) {
        return STR2INT_OVERFLOW;
    }
    if ((errno == ERANGE && l == LONG_MIN) || l < INT_MIN) {
        return STR2INT_UNDERFLOW;
    }
    if (*s == '\0' || *end != '\0') {
        return STR2INT_INCONVERTIBLE;
    }
    i = l;
    return STR2INT_SUCCESS;
}

/*
 * Converts the given CFURLRef to a C-String denoting a file system path.
 */
std::string GetPathFromCFURLRef(CFURLRef urlRef)
{
    char buffer[1024];
    std::string path;
    if(CFURLGetFileSystemRepresentation(urlRef, true, (UInt8*)buffer, 1024)) {
        path = std::string(buffer);
    }
    DLog(@"File System Path = %s\n", path.c_str());
    return path;
}

// -----------------------------------------------------------------------------
// MediaInfo Utility Functions
// -----------------------------------------------------------------------------
int GetNumberOfStreams(MediaInfo* MI, MediaInfoDLL::stream_t StreamType)
{
    String streamCount = MI->Get(StreamType, 0, "StreamCount", Info_Text).c_str();
    int noStreams = -1;
    if (str2int(noStreams, streamCount.c_str()) != STR2INT_SUCCESS) {
        ALog(@"Unbekannte Anzahl an Streams: %s\n", streamCount.c_str());
    }
    return noStreams;
}

// -----------------------------------------------------------------------------
// Main Import Function
// -----------------------------------------------------------------------------
Boolean ImportFile(CFMutableDictionaryRef attributes, CFURLRef urlForFile)
{
    Boolean dataProvided = FALSE;
    NSMutableDictionary* attributesDict = (NSMutableDictionary *)attributes;
    
    std::string path = GetPathFromCFURLRef(urlForFile);
    if (path.empty()) {
        ALog("Path[%@] could not be converted!", urlForFile);
        return FALSE;
    }
    
    MediaInfo MI;
    MI.Option("Info_Version", "0.7.58;MediaInfoImporter;0.0.1");
    MI.Option("Internet", "No");
    MI.Open(path.c_str());
    
    int noVideoStreams = GetNumberOfStreams(&MI, Stream_Video);
    int noAudioStreams = GetNumberOfStreams(&MI, Stream_Audio);
    
    int videoBitrateKbps = 0;
    int audioBitrateKbps = 0;
    
    NSString* videoCodec = @"";
    NSString* audioCodec = @"";
    
    // Video Stream related Information
    if (noVideoStreams > 0) {
        String width = MI.Get(Stream_Video, 0, "Width", Info_Text, Info_Name).c_str();
        if (!width.empty()) {
            int widthInt = 0;
            if (str2int(widthInt, width.c_str()) == STR2INT_SUCCESS) {
                [attributesDict setObject:[NSNumber numberWithInt:widthInt]
                                   forKey:(NSString *)kMDItemPixelWidth];
                DLog(@"Width = %d\n", widthInt);
                dataProvided = TRUE;
            }
        }
        
        String height = MI.Get(Stream_Video, 0, "Height", Info_Text, Info_Name).c_str();
        if (!height.empty()) {
            int heightInt = 0;
            if (str2int(heightInt, height.c_str()) == STR2INT_SUCCESS) {
                [attributesDict setObject:[NSNumber numberWithInt:heightInt]
                                   forKey:(NSString *)kMDItemPixelHeight];
                DLog(@"Height = %d\n", heightInt);
                dataProvided = TRUE;
            }
        }
        
        String videoBitrate = MI.Get(Stream_Video, 0, "BitRate", Info_Text, Info_Name).c_str();
        if (!videoBitrate.empty()) {
            int videoBitrateBps = 0;
            if (str2int(videoBitrateBps, videoBitrate.c_str()) == STR2INT_SUCCESS) {
                videoBitrateKbps = videoBitrateBps / 1000;
                [attributesDict setObject:[NSNumber numberWithInt:(videoBitrateKbps)]
                                   forKey:(NSString *)kMDItemVideoBitRate];
                DLog(@"Video Bitrate = %d\n", videoBitrateKbps);
                dataProvided = TRUE;
            }
        }
        
        String videoCodecTmp = MI.Get(Stream_Video, 0, "CodecID/Hint", Info_Text, Info_Name).c_str();
        if (videoCodecTmp.empty()) {
            // Codec Hint not present, use Format insteadt
            videoCodecTmp = MI.Get(Stream_Video, 0, "Format", Info_Text, Info_Name).c_str();
        }
        if (videoCodecTmp.compare("AVC") == 0) {
            // use Apple-friendly Name
            videoCodecTmp = "H.264";
        }
        videoCodec = [NSString stringWithCString:videoCodecTmp.c_str()
                                        encoding:NSUTF8StringEncoding];
        DLog(@"Video Codec = %@\n", videoCodec);
    }
    
    // Audio Stream related Information
    if (noAudioStreams > 0) {
        String audioBitrate = MI.Get(Stream_Audio, 0, "BitRate", Info_Text, Info_Name).c_str();
        if (!audioBitrate.empty()) {
            int audioBitrateBps = 0;
            if (str2int(audioBitrateBps, audioBitrate.c_str()) == STR2INT_SUCCESS) {
                audioBitrateKbps = audioBitrateBps / 1000;
                [attributesDict setObject:[NSNumber numberWithInt:(audioBitrateKbps)]
                                   forKey:(NSString *)kMDItemAudioBitRate];
                DLog(@"Audio Bitrate = %d\n", audioBitrateKbps);
                dataProvided = TRUE;
            }
        }
        
        String channels = MI.Get(Stream_Audio, 0, "Channels", Info_Text, Info_Name).c_str();
        if (!channels.empty()) {
            int noChannels = 0;
            if (str2int(noChannels, channels.c_str()) == STR2INT_SUCCESS) {
                [attributesDict setObject:[NSNumber numberWithInt:(noChannels)]
                                   forKey:(NSString *)kMDItemAudioChannelCount];
                DLog(@"Audio Channels = %d\n", noChannels);
                dataProvided = TRUE;
            }
        }
        
        String audioCodecTmp = MI.Get(Stream_Audio, 0, "CodecID/Hint", Info_Text, Info_Name).c_str();
        if (audioCodecTmp.empty()) {
            // Codec Hint not present, use Format insteadt
            audioCodecTmp = MI.Get(Stream_Audio, 0, "Format", Info_Text, Info_Name).c_str();
        }
        audioCodec = [NSString stringWithCString:audioCodecTmp.c_str()
                                        encoding:NSUTF8StringEncoding];
        DLog(@"Audio Codec = %@\n", audioCodec);
    }
    
    // General Information
    String duration = MI.Get(Stream_General, 0, "Duration", Info_Text, Info_Name).c_str();
    if (!duration.empty()) {
        int durationMillies = 0;
        if (str2int(durationMillies, duration.c_str()) == STR2INT_SUCCESS) {
            double durationSeconds = durationMillies / 1000.0;
            [attributesDict setObject:[NSNumber numberWithDouble:durationSeconds]
                               forKey:(NSString *)kMDItemDurationSeconds];
            DLog(@"Duration = %f\n", durationSeconds);
            dataProvided = TRUE;
        };
    }
    
    if (videoBitrateKbps > 0 || audioBitrateKbps > 0) {
        int totalBitrateKbps = videoBitrateKbps + audioBitrateKbps;
        [attributesDict setObject:[NSNumber numberWithInt:(totalBitrateKbps)]
                           forKey:(NSString *)kMDItemTotalBitRate];
    }

    if (noVideoStreams > 0 && noAudioStreams > 0) {
        [attributesDict setObject:[NSArray arrayWithObjects:@"Video", @"Sound", nil]
                           forKey:(NSString *)kMDItemMediaTypes];
        [attributesDict setObject:[NSArray arrayWithObjects:videoCodec, audioCodec, nil]
                           forKey:(NSString *)kMDItemCodecs];
    } else if (noVideoStreams > 0) {
        [attributesDict setObject:[NSArray arrayWithObject:@"Video"]
                           forKey:(NSString *)kMDItemMediaTypes];
        [attributesDict setObject:[NSArray arrayWithObject:videoCodec]
                           forKey:(NSString *)kMDItemCodecs];
    } else if (noAudioStreams > 0) {
        [attributesDict setObject:[NSArray arrayWithObject:@"Sound"]
                           forKey:(NSString *)kMDItemMediaTypes];
        [attributesDict setObject:[NSArray arrayWithObject:audioCodec]
                           forKey:(NSString *)kMDItemCodecs];
    }

    MI.Close();
    
    return dataProvided;
}
    //NSString stringWithUTF8String:width.c_str()

