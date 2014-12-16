// postinst.mm
// based on substrate



#import <Foundation/Foundation.h>

#ifndef kCFCoreFoundationVersionNumber_iOS_8_0
#define kCFCoreFoundationVersionNumber_iOS_8_0 1140.10
#endif

#define SubstrateBootstrap_ "/Library/Frameworks/CydiaSubstrate.framework/Libraries/SubstrateBootstrap.dylib"

int main() {
	NSString *AppIndexerPlist_;
	if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0) {
		AppIndexerPlist_ = @"/Library/LaunchDaemons/com.apple.search.appindexer.plist";
	} else {
		AppIndexerPlist_ = @"/System/Library/LaunchDaemons/com.apple.search.appindexer.plist";
	}
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// Change configuration by adding Substrate to DYLD_INSERT_LIBRARIES.
	
	NSMutableDictionary *root = [NSMutableDictionary dictionaryWithContentsOfFile:AppIndexerPlist_];
	if (root == nil) return 1;

	NSMutableDictionary *environment = [root objectForKey:@"EnvironmentVariables"];
	if (environment == nil) {
		environment = [NSMutableDictionary dictionaryWithCapacity:1];
		if (environment == nil) return 1;

		[root setObject:environment forKey:@"EnvironmentVariables"];
	}

	NSString *variable = [environment objectForKey:@"DYLD_INSERT_LIBRARIES"];
	if (variable == nil || [variable length] == 0)
		[environment setObject:@SubstrateBootstrap_ forKey:@"DYLD_INSERT_LIBRARIES"];
	else {
		NSArray *dylibs = [variable componentsSeparatedByString:@":"];
		if (dylibs == nil) return 1;

		NSUInteger index = [dylibs indexOfObject:@SubstrateBootstrap_];
		if (index != NSNotFound) return 0;

		[environment setObject:[NSString stringWithFormat:@"%@:%@", variable, @SubstrateBootstrap_] forKey:@"DYLD_INSERT_LIBRARIES"];
	}

	NSString *error;
	NSData *data = [NSPropertyListSerialization dataFromPropertyList:root format:NSPropertyListBinaryFormat_v1_0 errorDescription:&error];

	if (data == nil) return 1;
	if (![data writeToFile:AppIndexerPlist_ atomically:YES]) return 1;
	
	// Reload AppIndexer.
	
	system([[NSString stringWithFormat: @"launchctl unload %@", AppIndexerPlist_] UTF8String]);
	system([[NSString stringWithFormat: @"launchctl load %@", AppIndexerPlist_] UTF8String]);

	[pool drain];
	return 0;
}
