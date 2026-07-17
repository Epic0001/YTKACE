#import "YTKACEBackupManager.h"
#import "../../Runtime/Preferences.h"

#include <zlib.h>

static NSString * const YTKACEBackupErrorDomain = @"YTKACEBackup";

static NSError *YTKACEBackupError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:YTKACEBackupErrorDomain code:code
        userInfo:@{NSLocalizedDescriptionKey: message ?: @"Backup failed"}];
}

static void YTKACEAppend16(NSMutableData *data, uint16_t value) {
    uint8_t bytes[] = {(uint8_t)value, (uint8_t)(value >> 8)};
    [data appendBytes:bytes length:sizeof(bytes)];
}

static void YTKACEAppend32(NSMutableData *data, uint32_t value) {
    uint8_t bytes[] = {
        (uint8_t)value, (uint8_t)(value >> 8),
        (uint8_t)(value >> 16), (uint8_t)(value >> 24)
    };
    [data appendBytes:bytes length:sizeof(bytes)];
}

static uint16_t YTKACERead16(const uint8_t *bytes) {
    return (uint16_t)(bytes[0] | (bytes[1] << 8));
}

static uint32_t YTKACERead32(const uint8_t *bytes) {
    return (uint32_t)bytes[0] | ((uint32_t)bytes[1] << 8) |
        ((uint32_t)bytes[2] << 16) | ((uint32_t)bytes[3] << 24);
}

static NSString *YTKACERelativePath(NSURL *URL, NSURL *baseURL) {
    NSString *path = URL.URLByResolvingSymlinksInPath.path.stringByStandardizingPath;
    NSString *base = baseURL.URLByResolvingSymlinksInPath.path.stringByStandardizingPath;
    NSString *prefix = [base stringByAppendingString:@"/"];
    if (![path hasPrefix:prefix]) return nil;
    return [path substringFromIndex:prefix.length];
}

static NSDictionary *YTKACEBackupSettings(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
    NSDictionary *domain = bundleID.length == 0 ? @{} :
        [defaults persistentDomainForName:bundleID] ?: @{};
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    NSSet *named = [NSSet setWithArray:@[
        @"wiFiPlaybackIndex", @"celluarPlaybackIndex", @"sbSkipMode",
        @"sponsorBlock", @"clearonstartup", @"AudioNotificationOnSkip"
    ]];
    [domain enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        (void)stop;
        if ([key hasPrefix:@"YTKACE"] || [key hasPrefix:@"YTKPlus"] ||
            [key hasPrefix:@"kEnable"] || [key hasPrefix:@"kHide"] ||
            [key hasPrefix:@"kTab"] || [named containsObject:key]) {
            settings[key] = value;
        }
    }];
    return settings;
}

static void YTKACEApplyBackupSettings(NSDictionary *settings) {
    if (![settings isKindOfClass:NSDictionary.class]) return;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [settings enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        (void)stop;
        if ([key isKindOfClass:NSString.class] && value != nil) {
            [defaults setObject:value forKey:key];
        }
    }];
    [defaults synchronize];
}

static uint32_t YTKACECRCAndSize(NSURL *URL, uint32_t *size, NSError **error) {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingFromURL:URL error:error];
    if (handle == nil) return 0;
    uLong crc = crc32(0L, Z_NULL, 0);
    uint64_t total = 0;
    while (true) {
        NSData *chunk = [handle readDataOfLength:1024 * 1024];
        if (chunk.length == 0) break;
        crc = crc32(crc, (const Bytef *)chunk.bytes, (uInt)chunk.length);
        total += chunk.length;
        if (total > UINT32_MAX) {
            if (error != NULL) *error = YTKACEBackupError(2, @"A backup file is larger than 4 GB");
            [handle closeFile];
            return 0;
        }
    }
    [handle closeFile];
    *size = (uint32_t)total;
    return (uint32_t)crc;
}

static BOOL YTKACECopyFileToHandle(NSURL *URL, NSFileHandle *output, NSError **error) {
    NSFileHandle *input = [NSFileHandle fileHandleForReadingFromURL:URL error:error];
    if (input == nil) return NO;
    while (true) {
        NSData *chunk = [input readDataOfLength:1024 * 1024];
        if (chunk.length == 0) break;
        [output writeData:chunk];
    }
    [input closeFile];
    return YES;
}

static BOOL YTKACEWriteZip(NSURL *outputURL,
                           NSArray<NSDictionary *> *entries,
                           NSError **error) {
    NSFileManager *manager = NSFileManager.defaultManager;
    [manager removeItemAtURL:outputURL error:nil];
    [manager createFileAtPath:outputURL.path contents:nil attributes:nil];
    NSFileHandle *output = [NSFileHandle fileHandleForWritingToURL:outputURL error:error];
    if (output == nil) return NO;
    NSMutableArray<NSDictionary *> *central = [NSMutableArray array];
    for (NSDictionary *entry in entries) {
        NSURL *URL = entry[@"url"];
        NSData *name = [entry[@"name"] dataUsingEncoding:NSUTF8StringEncoding];
        if (name.length > UINT16_MAX) {
            if (error != NULL) *error = YTKACEBackupError(3, @"A backup path is too long");
            [output closeFile];
            return NO;
        }
        uint32_t size = 0;
        uint32_t crc = YTKACECRCAndSize(URL, &size, error);
        if (error != NULL && *error != nil) {
            [output closeFile];
            return NO;
        }
        uint64_t offset64 = output.offsetInFile;
        if (offset64 > UINT32_MAX) {
            if (error != NULL) *error = YTKACEBackupError(4, @"The backup is too large");
            [output closeFile];
            return NO;
        }
        NSMutableData *header = [NSMutableData data];
        YTKACEAppend32(header, 0x04034b50);
        YTKACEAppend16(header, 20);
        YTKACEAppend16(header, 0x0800);
        YTKACEAppend16(header, 0);
        YTKACEAppend16(header, 0);
        YTKACEAppend16(header, 0);
        YTKACEAppend32(header, crc);
        YTKACEAppend32(header, size);
        YTKACEAppend32(header, size);
        YTKACEAppend16(header, (uint16_t)name.length);
        YTKACEAppend16(header, 0);
        [header appendData:name];
        [output writeData:header];
        if (!YTKACECopyFileToHandle(URL, output, error)) {
            [output closeFile];
            return NO;
        }
        [central addObject:@{
            @"name": name, @"crc": @(crc), @"size": @(size),
            @"offset": @((uint32_t)offset64)
        }];
    }
    if (central.count > UINT16_MAX) {
        if (error != NULL) *error = YTKACEBackupError(5, @"The backup has too many files");
        [output closeFile];
        return NO;
    }
    uint32_t centralOffset = (uint32_t)output.offsetInFile;
    for (NSDictionary *entry in central) {
        NSData *name = entry[@"name"];
        NSMutableData *record = [NSMutableData data];
        YTKACEAppend32(record, 0x02014b50);
        YTKACEAppend16(record, 20);
        YTKACEAppend16(record, 20);
        YTKACEAppend16(record, 0x0800);
        YTKACEAppend16(record, 0);
        YTKACEAppend16(record, 0);
        YTKACEAppend16(record, 0);
        YTKACEAppend32(record, [entry[@"crc"] unsignedIntValue]);
        YTKACEAppend32(record, [entry[@"size"] unsignedIntValue]);
        YTKACEAppend32(record, [entry[@"size"] unsignedIntValue]);
        YTKACEAppend16(record, (uint16_t)name.length);
        YTKACEAppend16(record, 0);
        YTKACEAppend16(record, 0);
        YTKACEAppend16(record, 0);
        YTKACEAppend16(record, 0);
        YTKACEAppend32(record, 0);
        YTKACEAppend32(record, [entry[@"offset"] unsignedIntValue]);
        [record appendData:name];
        [output writeData:record];
    }
    uint32_t centralSize = (uint32_t)output.offsetInFile - centralOffset;
    NSMutableData *end = [NSMutableData data];
    YTKACEAppend32(end, 0x06054b50);
    YTKACEAppend16(end, 0);
    YTKACEAppend16(end, 0);
    YTKACEAppend16(end, (uint16_t)central.count);
    YTKACEAppend16(end, (uint16_t)central.count);
    YTKACEAppend32(end, centralSize);
    YTKACEAppend32(end, centralOffset);
    YTKACEAppend16(end, 0);
    [output writeData:end];
    [output closeFile];
    return YES;
}

static NSArray<NSDictionary *> *YTKACEBackupEntries(NSError **error) {
    NSFileManager *manager = NSFileManager.defaultManager;
    NSURL *root = YTKACEApplicationSupportDirectory();
    NSURL *settingsURL = [root URLByAppendingPathComponent:@"SettingsBackup.plist"];
    if (![YTKACEBackupSettings() writeToURL:settingsURL atomically:YES]) {
        if (error != NULL) *error = YTKACEBackupError(6, @"Settings could not be saved");
        return nil;
    }
    NSMutableArray<NSDictionary *> *entries = [NSMutableArray arrayWithObject:@{
        @"url": settingsURL, @"name": @"SettingsBackup.plist"
    }];
    NSURL *downloads = [root URLByAppendingPathComponent:@"Downloads" isDirectory:YES];
    NSDirectoryEnumerator<NSURL *> *items = [manager enumeratorAtURL:downloads
        includingPropertiesForKeys:@[NSURLIsRegularFileKey]
                           options:NSDirectoryEnumerationSkipsHiddenFiles
                      errorHandler:nil];
    for (NSURL *URL in items) {
        NSNumber *regular = nil;
        [URL getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];
        if (!regular.boolValue) continue;
        NSString *relative = YTKACERelativePath(URL, downloads);
        if (relative.length == 0) continue;
        [entries addObject:@{
            @"url": URL,
            @"name": [@"Downloads" stringByAppendingPathComponent:relative]
        }];
    }
    return entries;
}

static BOOL YTKACEExtractStoredZip(NSURL *URL, NSURL *destination, NSError **error) {
    NSFileHandle *input = [NSFileHandle fileHandleForReadingFromURL:URL error:error];
    if (input == nil) return NO;
    NSFileManager *manager = NSFileManager.defaultManager;
    while (true) {
        NSData *fixed = [input readDataOfLength:30];
        if (fixed.length == 0) break;
        if (fixed.length < 4) {
            if (error != NULL) *error = YTKACEBackupError(7, @"The backup is incomplete");
            [input closeFile];
            return NO;
        }
        const uint8_t *bytes = (const uint8_t *)fixed.bytes;
        uint32_t signature = YTKACERead32(bytes);
        if (signature == 0x02014b50 || signature == 0x06054b50) break;
        if (signature != 0x04034b50 || fixed.length != 30) {
            if (error != NULL) *error = YTKACEBackupError(8, @"This is not a YTKACE backup");
            [input closeFile];
            return NO;
        }
        uint16_t flags = YTKACERead16(bytes + 6);
        uint16_t method = YTKACERead16(bytes + 8);
        uint32_t expectedCRC = YTKACERead32(bytes + 14);
        uint32_t compressedSize = YTKACERead32(bytes + 18);
        uint32_t size = YTKACERead32(bytes + 22);
        uint16_t nameLength = YTKACERead16(bytes + 26);
        uint16_t extraLength = YTKACERead16(bytes + 28);
        if ((flags & 0x0008) != 0 || method != 0 || compressedSize != size) {
            if (error != NULL) *error = YTKACEBackupError(9, @"Unsupported ZIP compression");
            [input closeFile];
            return NO;
        }
        NSData *nameData = [input readDataOfLength:nameLength];
        NSString *name = [[NSString alloc] initWithData:nameData encoding:NSUTF8StringEncoding];
        if (extraLength != 0) [input readDataOfLength:extraLength];
        NSString *clean = name.stringByStandardizingPath;
        BOOL allowed = [clean isEqualToString:@"SettingsBackup.plist"] ||
            [clean hasPrefix:@"Downloads/"];
        if (!allowed || [clean isEqualToString:@".."] ||
            [clean hasPrefix:@"/"] || [clean containsString:@"../"]) {
            if (error != NULL) *error = YTKACEBackupError(10, @"The backup contains an unsafe path");
            [input closeFile];
            return NO;
        }
        NSURL *outputURL = [destination URLByAppendingPathComponent:clean];
        [manager createDirectoryAtURL:outputURL.URLByDeletingLastPathComponent
          withIntermediateDirectories:YES attributes:nil error:nil];
        [manager createFileAtPath:outputURL.path contents:nil attributes:nil];
        NSFileHandle *output = [NSFileHandle fileHandleForWritingToURL:outputURL error:error];
        if (output == nil) {
            [input closeFile];
            return NO;
        }
        uint32_t remaining = size;
        uLong crc = crc32(0L, Z_NULL, 0);
        while (remaining != 0) {
            NSUInteger amount = MIN((uint32_t)(1024 * 1024), remaining);
            NSData *chunk = [input readDataOfLength:amount];
            if (chunk.length != amount) {
                [output closeFile];
                [input closeFile];
                if (error != NULL) *error = YTKACEBackupError(11, @"The backup is incomplete");
                return NO;
            }
            [output writeData:chunk];
            crc = crc32(crc, (const Bytef *)chunk.bytes, (uInt)chunk.length);
            remaining -= (uint32_t)chunk.length;
        }
        [output closeFile];
        if ((uint32_t)crc != expectedCRC) {
            [input closeFile];
            if (error != NULL) *error = YTKACEBackupError(12, @"A backup file is damaged");
            return NO;
        }
    }
    [input closeFile];
    return YES;
}

static void YTKACERestoreDownloads(NSURL *source, NSURL *destination) {
    NSFileManager *manager = NSFileManager.defaultManager;
    NSDirectoryEnumerator<NSURL *> *items = [manager enumeratorAtURL:source
        includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                           options:0 errorHandler:nil];
    for (NSURL *URL in items) {
        NSNumber *directory = nil;
        [URL getResourceValue:&directory forKey:NSURLIsDirectoryKey error:nil];
        if (directory.boolValue) continue;
        NSString *relative = YTKACERelativePath(URL, source);
        NSArray<NSString *> *components = relative.pathComponents;
        NSUInteger categoryIndex = NSNotFound;
        NSString *category = nil;
        for (NSUInteger index = 0; index < components.count; index++) {
            for (NSString *candidate in @[@"Video", @"Audio", @"Shorts"]) {
                if ([components[index] caseInsensitiveCompare:candidate] == NSOrderedSame) {
                    categoryIndex = index;
                    category = candidate;
                    break;
                }
            }
            if (categoryIndex != NSNotFound) break;
        }
        if (categoryIndex == NSNotFound || categoryIndex + 1 >= components.count) continue;
        NSURL *target = [destination URLByAppendingPathComponent:category isDirectory:YES];
        for (NSUInteger index = categoryIndex + 1; index < components.count; index++) {
            target = [target URLByAppendingPathComponent:components[index]];
        }
        [manager createDirectoryAtURL:target.URLByDeletingLastPathComponent
          withIntermediateDirectories:YES attributes:nil error:nil];
        [manager removeItemAtURL:target error:nil];
        [manager copyItemAtURL:URL toURL:target error:nil];
    }
}

@implementation YTKACEBackupManager

+ (void)createBackupWithCompletion:(YTKACEBackupCreationCompletion)completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSError *error = nil;
        NSURL *root = YTKACEApplicationSupportDirectory();
        NSURL *backups = [root URLByAppendingPathComponent:@"Backups" isDirectory:YES];
        [NSFileManager.defaultManager createDirectoryAtURL:backups
          withIntermediateDirectories:YES attributes:nil error:nil];
        NSDateFormatter *formatter = [NSDateFormatter new];
        formatter.dateFormat = @"yyyyMMdd-HHmmss";
        NSString *name = [NSString stringWithFormat:@"YTKACE-Backup-%@.zip",
            [formatter stringFromDate:NSDate.date]];
        NSURL *URL = [backups URLByAppendingPathComponent:name];
        NSArray *entries = YTKACEBackupEntries(&error);
        if (entries != nil && !YTKACEWriteZip(URL, entries, &error)) URL = nil;
        dispatch_async(dispatch_get_main_queue(), ^{ completion(URL, error); });
    });
}

+ (void)restoreBackupFromURL:(NSURL *)URL
                  completion:(YTKACEBackupRestoreCompletion)completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSFileManager *manager = NSFileManager.defaultManager;
        NSError *error = nil;
        NSURL *temporary = [YTKACEApplicationSupportDirectory()
            URLByAppendingPathComponent:[@"Restore-" stringByAppendingString:NSUUID.UUID.UUIDString]
                             isDirectory:YES];
        [manager createDirectoryAtURL:temporary withIntermediateDirectories:YES
                           attributes:nil error:nil];
        if (YTKACEExtractStoredZip(URL, temporary, &error)) {
            NSURL *restoredDownloads = [temporary URLByAppendingPathComponent:@"Downloads"
                                                                   isDirectory:YES];
            NSURL *downloads = [YTKACEApplicationSupportDirectory()
                URLByAppendingPathComponent:@"Downloads" isDirectory:YES];
            if ([manager fileExistsAtPath:restoredDownloads.path]) {
                [manager createDirectoryAtURL:downloads withIntermediateDirectories:YES
                                   attributes:nil error:nil];
                YTKACERestoreDownloads(restoredDownloads, downloads);
            }
            NSDictionary *settings = [NSDictionary dictionaryWithContentsOfURL:
                [temporary URLByAppendingPathComponent:@"SettingsBackup.plist"]];
            YTKACEApplyBackupSettings(settings);
        }
        [manager removeItemAtURL:temporary error:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error == nil) {
                [NSNotificationCenter.defaultCenter
                    postNotificationName:@"YTKACEDownloadLibraryChanged" object:nil];
            }
            completion(error);
        });
    });
}

@end
