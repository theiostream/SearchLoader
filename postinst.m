// postinst.mm
// based on substrate

#import <Foundation/Foundation.h>

static NSString * const TLSubstrateBootstrapPath = @"/Library/Frameworks/CydiaSubstrate.framework/Libraries/SubstrateBootstrap.dylib";

int main(int argc, char **argv) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	// Try /System/Library/LaunchDaemons/
	NSString *appIndexerPlist = @"/System/Library/LaunchDaemons/com.apple.search.appindexer.plist";
	NSMutableDictionary *appIndexerJobOptions = [NSMutableDictionary dictionaryWithContentsOfFile:appIndexerPlist];

	// Try /Library/LaunchDaemons/
	if (appIndexerPlist == nil) {
		appIndexerPlist = @"/Library/LaunchDaemons/com.apple.search.appindexer.plist";
		appIndexerJobOptions = [NSMutableDictionary dictionaryWithContentsOfFile:appIndexerPlist];

		// Give up
		if (appIndexerPlist == nil) 
			return 1;
	}

	NSMutableDictionary *environmentVariables = [[[appIndexerJobOptions objectForKey:@"EnvironmentVariables"] mutableCopy] autorelease];

	if (environmentVariables == nil) {
		environmentVariables = [NSMutableDictionary dictionaryWithCapacity:1];
		if (environmentVariables == nil)
			return 1;
	}

	NSString *libraryList = [environmentVariables objectForKey:@"DYLD_INSERT_LIBRARIES"];

	if (libraryList == nil || [libraryList length] == 0) {
		[environmentVariables setObject:TLSubstrateBootstrapPath forKey:@"DYLD_INSERT_LIBRARIES"];		
	} else {
		NSArray *insertedLibraries = [libraryList componentsSeparatedByString:@":"];
		if (insertedLibraries == nil)
			return 1;

		NSUInteger index = [insertedLibraries indexOfObject:TLSubstrateBootstrapPath];
		if (index != NSNotFound)
			return 0;

		[environmentVariables setObject:[NSString stringWithFormat:@"%@:%@", libraryList, TLSubstrateBootstrapPath] forKey:@"DYLD_INSERT_LIBRARIES"];
	}

	[appIndexerJobOptions setObject:environmentVariables forKey:@"EnvironmentVariables"];

	if (![appIndexerJobOptions writeToFile:appIndexerPlist atomically:YES])
		return 1;
	
	// Reload AppIndexer.
	system([[NSString stringWithFormat:@"launchctl unload %@", appIndexerPlist] UTF8String]);
	system([[NSString stringWithFormat:@"launchctl load %@", appIndexerPlist] UTF8String]);

	[pool drain];

	return 0;
}
