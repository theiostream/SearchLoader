/*%%%%%
%% TLListener.xm
%% SearchLoader <--> Spotlight+
%%
%% Listeners took me three days to make and now are deleted.
%% Search Bundles took me two more days to find out.
%% Plus Spotlight Bundles took me one week.
%% Please do not harm these few lines.
%% -- theiostream (7/12/12)
%%%%%*/

// Even though this has nothing to do with WeeLoader's code it borrows some things, like:
// - Thread Dictionary key setting;
// - Hooking +[NSBundle bundleWithPath:] and -[NSFileManager contentsOfDirectoryWithPath:error:]
// So, thanks to http://github.com/Xuzz/WeeLoader :)

#include <string.h>

#include <notify.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#include <mach-o/dyld.h> // Yeah.

#import <SearchLoader/TLLibrary.h>
#define kTLExtendedQueryingKey @"TLExtendedQuerying"
#define kTLInternetQueryingKey @"TLInternetQuerying"
#define kTLLoadingBundlesKey @"TLLoadingBundles"

#define kTLDefaultSearchBundleDirectory @"/System/Library/SearchBundles/"
#define kTLCustomSearchBundleDirectory @"/Library/SearchLoader/SearchBundles/"
#define kTLInternalOS6SearchBundleDirectory @"/Library/SearchLoader/Internal/OS6/"

#define TLFileExists(file) [[NSFileManager defaultManager] fileExistsAtPath: file ]

// Any way to cache the thread dictionary?
static BOOL TLGetThreadKey(NSString *key) {
	NSDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
	return [[threadDictionary objectForKey:key] boolValue];
}

static void TLSetThreadKey(NSString *key, BOOL value) {
	NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
	[threadDictionary setObject:[NSNumber numberWithBool:value] forKey:key];
}

static BOOL TLConstructorIsPad() {
	size_t size = 12;
	char machine[12];
	sysctlbyname("hw.machine", (char *)machine, &size, NULL, 0);
	
	return strstr(machine, "iPad") != NULL;
}

static inline UIImage *TLPadImageForDisplayID(NSString *displayID) {
	return [%c(UIImage) imageWithContentsOfFile:[NSString stringWithFormat:@"/Library/SearchLoader/Missing/%@.png", displayID]];
}

static inline BOOL TLHasSpotlightPlus() {
	return access("/Library/MobileSubstrate/DynamicLibraries/SpotlightPlus.dylib", F_OK) != -1;
}

static inline BOOL TLIsInProcess(const char *process) {
	char proc[PATH_MAX];
	uint32_t size = sizeof(proc);
	
	_NSGetExecutablePath(proc, &size);
	return strstr(proc, process) != NULL;
}

// ------

static void _TLSetNeedsInternet(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	uint64_t state;
	int token;
	
	notify_register_check("am.theiostre.searchloader.INTERNALNET", &token);
	notify_get_state(token, &state);
	notify_cancel(token);
	
	//TLSetNeedsInternet((state != 0));
	TLSetThreadKey(kTLInternetQueryingKey, (state != 0));
}

// ------

// Global

// TODO: Now we don't need whole bundles, just plists (for this)
// TODO: Investigate hooking SPAllDomainsVector.
MSHook(NSArray *, SPGetExtendedDomains) {
	NSLog(@"how am I being recursively called? good question!");
	
	NSMutableArray *ret = [NSMutableArray arrayWithArray:_SPGetExtendedDomains()];
	NSMutableArray *internet = [NSMutableArray array];
	
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *path = @"/Library/SearchLoader/Applications/";
	NSArray *contents = [fm contentsOfDirectoryAtPath:path error:nil];
	
	for (NSString *file in contents) {
		if ([[file pathExtension] isEqualToString:@"bundle"]) {
			NSBundle *bundle = [NSBundle bundleWithPath:[path stringByAppendingString:file]];
			NSDictionary *info = [bundle infoDictionary];
			NSString *displayID = [info objectForKey:@"SPDisplayIdentifier"];
			
			// SBSCopyBundlePathForDisplayIdentifier freezes. We may need a new thread here or something.
			/*NSString *(*SBSCopyBundlePathForDisplayIdentifier)(NSString *) = (NSString *(*)(NSString *))dlsym(RTLD_DEFAULT, "SBSCopyBundlePathForDisplayIdentifier");
			if (!(*SBSCopyBundlePathForDisplayIdentifier)(displayID)) {
				if (![[info objectForKey:@"TLForceAppForSpotlightPlus"] boolValue]) continue;
				if (!TLHasSpotlightPlus()) continue;
			}*/
			
			if ([[info objectForKey:@"TLIsSearchBundle"] boolValue]) {
				if (TLGetThreadKey(kTLExtendedQueryingKey) || TLIsInProcess("AppIndexer")) continue;
			}

			NSMutableDictionary *dict = [NSMutableDictionary dictionary];
			[dict setObject:displayID forKey:@"SPDisplayIdentifier"];
			[dict setObject:[info objectForKey:@"SPCategory"] forKey:@"SPCategory"];
			if ([info objectForKey:@"SPRequiredCapabilities"]) [dict setObject:[info objectForKey:@"SPRequiredCapabilities"] forKey:@"SPRequiredCapabilities"];
			if ([info objectForKey:@"TLDisplayName"]) [dict setObject:[info objectForKey:@"TLDisplayName"] forKey:@"TLDisplayName"];

			NSMutableArray *tgt = [[info objectForKey:@"TLUsesInternet"] boolValue] ? internet : ret;
			[tgt addObject:dict];
		}
	}
	
	[ret addObjectsFromArray:internet];
	
	return ret;
}

// TODO: Support Localization.
MSHook(NSString *, SPDisplayNameForExtendedDomain, int domain) {
	NSString *(*SPDisplayIdentifierForDomain)(int) = (NSString *(*)(int))dlsym(RTLD_DEFAULT, "SPDisplayIdentifierForDomain");
	NSString *(*SPCategoryForDomain)(int) = (NSString *(*)(int))dlsym(RTLD_DEFAULT, "SPCategoryForDomain");
	NSArray *(*SPGetExtendedDomains)() = (NSArray *(*)())dlsym(RTLD_DEFAULT, "SPGetExtendedDomains");

	NSString *category = SPCategoryForDomain(domain);

	NSString *ret = _SPDisplayNameForExtendedDomain(domain);
	if ([ret isEqualToString:category]) {
		NSArray *extendedDomains = SPGetExtendedDomains();

		for (NSDictionary *dom in extendedDomains) {
			if ([[dom objectForKey:@"SPDisplayIdentifier"] isEqualToString:SPDisplayIdentifierForDomain(domain)]) {
				ret = [dom objectForKey:@"TLDisplayName"] ?: ret;
			}
		}
	}

	return ret;
}

// SpringBoard

%hook SBSearchModel
%group TLSpringBoardHooks
- (void)setQueryString:(NSString *)string {
	// This bypasses some sort of Apple's optimization system.
	// Since logically: If there was no result for "Nol", "Nolan" would be impossible, so it doesn't search for that at all.
	// Yet, with Calculator: "1-" is invalid, yet "1-1" is not.
	// Therefore we bypass this check, sacrificing some performance.
	// For more details, reverse -[SBSearchModel _shouldIgnoreQuery:]
	
	const char *hook = TLIsOS6 ? "_prefixWithNoResults" : "_firstNoResultsQuery";
	MSHookIvar<NSString *>(self, hook) = [NSString string];
	%orig;
}
%end

%group TLOS5SpringBoardHooks
// Let's hope this works.
- (BOOL)_shouldDisplayWebSearchResults {
	NSLog(@"-[SBSearchModel _shouldDisplayWebResults]: (Internet) %d", TLGetThreadKey(kTLInternetQueryingKey));
	return %orig || TLGetThreadKey(kTLInternetQueryingKey);
}

- (void)searchDaemonQueryCompleted:(id)query {
	TLSetThreadKey(kTLInternetQueryingKey, NO); // So we don't end up in shit because of shitty developers.
	%orig;
}
%end

%group TLOS6SpringBoardHooks
/*- (void)addSections:(NSArray *)sections {
	%log;
	int *len = MSHookIvar<int *>(self, "_replacementGroupLengths");
	int rg = MSHookIvar<int>(self, "_latestCurrentReplacementGroup");
	int ls = MSHookIvar<int>(self, "_latestCurrentSection");
	NSLog(@"latest current replacement group %d; length %d; latest section %d", rg, len[rg], ls);
	
	//MSHookIvar<int>(self, "_latestCurrentSection") = 

	if ([sections count] == 1 && [(SPSearchResultSection *)[sections objectAtIndex:0] domain] == 1) return;
	%orig;
}*/
%end

%group TLPadOS5SpringBoardHooks
- (UIImage *)imageForDomain:(NSInteger)domain andDisplayID:(NSString *)displayID {
	UIImage *img = TLPadImageForDisplayID(displayID);
	return img ?: %orig;
}
%end

%group TLPadOS6SpringBoardHooks
- (UIImage *)_imageForDomain:(NSInteger)domain andDisplayID:(NSString *)displayID {
	UIImage *img = TLPadImageForDisplayID(displayID);
	return img ?: %orig;
}
%end
%end

// searchd

/* This hook took me 3 days */
%group TLExtendedHooks
%hook SPExtendedDatastore
- (NSArray *)searchDomains {
	TLSetThreadKey(kTLExtendedQueryingKey, YES);
	NSArray *ret = %orig;
	TLSetThreadKey(kTLExtendedQueryingKey, NO);
	
	return ret;
}
%end
%end

%group TLSearchdHooks
%hook SPBundleManager
- (void)_loadSearchBundles {
	TLSetThreadKey(kTLLoadingBundlesKey, YES);
	%orig;
	TLSetThreadKey(kTLLoadingBundlesKey, NO);
	
	%init(TLExtendedHooks);
}
%end

%hook NSFileManager
- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error {
	if (TLGetThreadKey(kTLLoadingBundlesKey)) {
		NSArray *system = %orig;
		NSArray *custom = %orig(kTLCustomSearchBundleDirectory, error);
		//if (TLIsOS6) custom = [%orig(kTLInternalOS6SearchBundleDirectory, error) arrayByAddingObjectsFromArray:custom];

		NSLog(@"it worked we got sys=%@ and custom=%@", system, custom);
		return [system arrayByAddingObjectsFromArray:custom];
	}
	
	return %orig;
}
%end

%hook NSBundle
- (NSBundle *)initWithPath:(NSString *)path {
	if (TLGetThreadKey(kTLLoadingBundlesKey)) {
		%log;

		NSBundle *bundle = %orig;
		if (bundle == nil && [path hasPrefix:kTLDefaultSearchBundleDirectory]) {
			NSString *bundlename = [path substringFromIndex:[kTLDefaultSearchBundleDirectory length]];
			NSLog(@"bundle name=%@", bundlename);

			path = [kTLCustomSearchBundleDirectory stringByAppendingString:bundlename];
			if (TLFileExists(path)) {
				bundle = [[NSBundle alloc] initWithPath:path];
			}

			/*else {
				path = [kTLInternalOS6SearchBundleDirectory stringByAppendingString:bundlename];
				if (TLFileExists(path)) {
					bundle = [[NSBundle alloc] initWithPath:path];
				}
			} */
		}
		
		return bundle;
	}
	
	return %orig;
}
%end
%end

%group TLOS5SearchdHooks
%hook SDClient
- (void)_cancelQueryWithExternalID:(unsigned int)externalID {
	if (TLGetThreadKey(kTLExtendedQueryingKey)) TLSetThreadKey(kTLExtendedQueryingKey, NO);
	%orig;
}
%end
%end

%group TLOS6SearchdHooks
// This allows us to make the query wait for async completion of a datastore (allowing *some* cases to be resolved without complex run loops)
%hook SDSearchQuery
- (void)storeCompletedSearch:(NSObject<TLSearchDatastore> *)datastore {
	if ([datastore respondsToSelector:@selector(blockDatastoreComplete)] && [datastore blockDatastoreComplete])
		return;
	
	%orig;
}
%end

// This makes sure the kTLExtendedQueryingKey thread key is accurate.
%hook SDClient
- (void)removeActiveQuery:(id)query {
	if (TLGetThreadKey(kTLExtendedQueryingKey)) TLSetThreadKey(kTLExtendedQueryingKey, NO);
	%orig;
}
%end
%end

// Preferences

%group TLPreferencesHooks
%hook PSRootController
+ (BOOL)processedBundle:(NSDictionary *)specifier parentController:(id)arg2 parentSpecifier:(id)arg3 bundleControllers:(id *)arg4 settings:(id)arg5 {
	static BOOL $processedSearchBundle = NO;
	
	BOOL ret = %orig;
	if (!$processedSearchBundle && [[specifier objectForKey:@"bundle"] isEqualToString:@"SearchSettings"]) {
		NSLog(@"[SearchLoader] Inserting inside SearchSettings.bundle...");
		
		MSHookFunction(MSFindSymbol(MSGetImageByName("/System/Library/PrivateFrameworks/Search.framework/Search"), "_SPGetExtendedDomains"), MSHake(SPGetExtendedDomains));
		MSHookFunction(MSFindSymbol(MSGetImageByName("/System/Library/PrivateFrameworks/Search.framework/Search"), "_SPDisplayNameForExtendedDomain"), MSHake(SPDisplayNameForExtendedDomain));
		$processedSearchBundle = YES;
	}

	return ret;
}
%end
%end

%ctor {
	NSLog(@"[SearchLoader] In Soviet Russia, burgers eat YOU!");
	
	// Preferences is special.
	if ([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.Preferences"]) {
		%init(TLPreferencesHooks);
		return;
	}
	
	%init; // DEBUG. Nothing is actually inside _ungrouped.
	MSHookFunction(MSFindSymbol(MSGetImageByName("/System/Library/PrivateFrameworks/Search.framework/Search"), "_SPGetExtendedDomains"), MSHake(SPGetExtendedDomains));
	MSHookFunction(MSFindSymbol(MSGetImageByName("/System/Library/PrivateFrameworks/Search.framework/Search"), "_SPDisplayNameForExtendedDomain"), MSHake(SPDisplayNameForExtendedDomain));
	//MSHookFunction(MSFindSymbol(NULL, "_SBSCopyBundlePathForDisplayIdentifier"), (void *)&$SBSCopyBundlePathForDisplayIdentifier, (void **)&_SBSCopyBundlePathForDisplayIdentifier);
	
	if ([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) {
		%init(TLSpringBoardHooks);
		
		if (TLIsOS6) {
			%init(TLOS6SpringBoardHooks);
			if (TLConstructorIsPad()) %init(TLPadOS6SpringBoardHooks);
		}
		else {
			%init(TLOS5SpringBoardHooks);
			if (TLConstructorIsPad()) %init(TLPadOS5SpringBoardHooks);
		}
	}
	
	else if (TLIsInProcess("searchd")) {
		%init(TLSearchdHooks);
		if (!TLIsOS6) %init(TLOS5SearchdHooks);
		else %init(TLOS6SearchdHooks);
	}

	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, &_TLSetNeedsInternet, CFSTR("am.theiostre.searchloader.INTERNALNET"), NULL, 0);
}

