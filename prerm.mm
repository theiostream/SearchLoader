// prerm.mm
// based on substrate's postrm.mm

#include <Foundation/Foundation.h>

#define AppIndexerPlist_ "/System/Library/LaunchDaemons/com.apple.search.appindexer.plist"
#define SubstrateBootstrap_ "/Library/Frameworks/CydiaSubstrate.framework/Libraries/SubstrateBootstrap.dylib"
int main() {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSMutableDictionary *root = [NSMutableDictionary dictionaryWithContentsOfFile:@AppIndexerPlist_];
	if (root == nil)
		return 1;
	
	NSMutableDictionary *environment = [root objectForKey:@"EnvironmentVariables"];
	if (environment == nil)
		return 0;
	
	NSString *variable = [environment objectForKey:@"DYLD_INSERT_LIBRARIES"];
	if (variable == nil)
		return 0;
	
	NSMutableArray *dylibs = [NSMutableArray arrayWithArray:[variable componentsSeparatedByString:@":"]];
	if (dylibs == nil)
		return 1;
	
	NSUInteger index = [dylibs indexOfObject:@SubstrateBootstrap_];
	if (index == NSNotFound)
		return 0;
	
	[dylibs removeObject:@SubstrateBootstrap_];

	if ([dylibs count] != 0)
		[environment setObject:[dylibs componentsJoinedByString:@":"] forKey:@"DYLD_INSERT_LIBRARIES"];
	else if ([environment count] == 1)
		[root removeObjectForKey:@"EnvironmentVariables"];
	else
		[environment removeObjectForKey:@"DYLD_INSERT_LIBRARIES"];
	
	NSData *data = [NSPropertyListSerialization dataFromPropertyList:root format:NSPropertyListBinaryFormat_v1_0 errorDescription:nil];
	if (data == nil)
		return 1;
	
	if (![data writeToFile:@AppIndexerPlist_ atomically:YES])
		return 1;
	
	[pool drain];
	return 0;
}
