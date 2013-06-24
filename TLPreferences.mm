#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <libprefs/prefs.h>
#import <Foundation/Foundation.h>
#include <dlfcn.h>

@interface UIDevice (SearchLoaderPreferences)
- (BOOL)isWildcat;
@end

static NSString **pPSTableCellUseEtchedAppearanceKey = NULL;

static NSInteger PSSpecifierSort(PSSpecifier *a1, PSSpecifier *a2, void *context) {
	NSString *string1 = [a1 name];
	NSString *string2 = [a2 name];
	
	return [string1 localizedCaseInsensitiveCompare:string2];
}

@interface TLPreferencesListController : PSListController
@end

@implementation TLPreferencesListController
- (void)setValue:(NSNumber *)value forSpecifier:(PSSpecifier *)specifier {
	[self setPreferenceValue:value specifier:specifier];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSNumber *)getValueForSpecifier:(PSSpecifier *)specifier {
	return [self readPreferenceValue:specifier];
}

- (NSArray *)specifiers {
	if (!_specifiers) {
		NSMutableArray *$specifiers = [NSMutableArray array];
		
		BOOL added_ui = NO;
		if (access("/Library/MobileSubstrate/DynamicLibraries/SpotlightUI.dylib", F_OK) == 0) {
			NSArray *tweakSpecifiers = [self loadSpecifiersFromPlistName:@"SpotlightUI" target:self];
			[$specifiers addObjectsFromArray:tweakSpecifiers];

			added_ui = YES;
		}
		
		NSArray *groups = [self loadSpecifiersFromPlistName:@"Groups" target:self];
		[$specifiers addObjectsFromArray:groups];
		
		// [19:20:56] <DHowett> you have my blessing.
		// Also, this is PreferenceLoader's code.
		NSMutableArray *loadedSpecifiers = [NSMutableArray array];
		
		NSArray *subpaths = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:@"/Library/SearchLoader/Preferences" error:NULL];
		for (NSString *item in subpaths) {
			if (![[item pathExtension] isEqualToString:@"plist"]) continue;
			NSString *fullpath = [@"/Library/SearchLoader/Preferences/" stringByAppendingString:item];
			NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:fullpath];

			NSDictionary *entry = [plist objectForKey:@"entry"];
			if (!entry) continue;
			
			NSArray *specifiers = [self specifiersFromEntry:entry sourcePreferenceLoaderBundlePath:[fullpath stringByDeletingLastPathComponent] title:[[item lastPathComponent] stringByDeletingPathExtension]];
			if (!specifiers) continue;

			if (pPSTableCellUseEtchedAppearanceKey && [UIDevice instancesRespondToSelector:@selector(isWildcat)] && [[UIDevice currentDevice] isWildcat]) {
				for (PSSpecifier *specifier in specifiers) {
					[specifier setProperty:[NSNumber numberWithBool:YES] forKey:*pPSTableCellUseEtchedAppearanceKey];
				}
			}

			[loadedSpecifiers addObjectsFromArray:specifiers];
		}

		[loadedSpecifiers sortUsingFunction:&PSSpecifierSort context:NULL];

		NSIndexSet *indices = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(added_ui ? 5 : 3, [loadedSpecifiers count])];
		[$specifiers insertObjects:loadedSpecifiers atIndexes:indices];
		
		// I think they deserve some credit.
		if (access("/Library/SearchLoader/Internal/extendedwatcher.dat", F_OK) == 0) {
			PSSpecifier *arielEliranCredits = [PSSpecifier emptyGroupSpecifier];
			[arielEliranCredits setProperty:@"Search Results were designed by Eliran Manzeli and Ariel Aouizerate, and coded by Daniel Ferreira." forKey:@"footerText"];
			[$specifiers insertObject:arielEliranCredits atIndex:(added_ui ? 5 : 3) + [loadedSpecifiers count]];
		}

		_specifiers = [[NSArray alloc] initWithArray:$specifiers];
	}

	return _specifiers;
}
@end

__attribute__((constructor))
static void TLPreferencesBundleConstructor() {
	void *preferencesHandle = dlopen("/System/Library/PrivateFrameworks/Preferences.framework/Preferences", RTLD_LAZY | RTLD_NOLOAD);
	if (preferencesHandle) {
		pPSTableCellUseEtchedAppearanceKey = (NSString **)dlsym(preferencesHandle, "PSTableCellUseEtchedAppearanceKey");
		dlclose(preferencesHandle);
	}
}
