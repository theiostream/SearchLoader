// postinst.mm
// based on substrate

#import <Foundation/Foundation.h>

#define AppIndexerPlist_ "/System/Library/LaunchDaemons/com.apple.search.appindexer.plist"
#define SubstrateBootstrap_ "/Library/Frameworks/CydiaSubstrate.framework/Libraries/SubstrateBootstrap.dylib"

int main() {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// Change configuration by adding Substrate to DYLD_INSERT_LIBRARIES.
	NSString *file = @AppIndexerPlist_;

	NSMutableDictionary *root = [NSMutableDictionary dictionaryWithContentsOfFile:file];
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
	if (![data writeToFile:file atomically:YES]) return 1;
	
	// Reload AppIndexer.
	system("launchctl unload " AppIndexerPlist_);
	system("launchctl load " AppIndexerPlist_);

	[pool drain];
	return 0;
}
