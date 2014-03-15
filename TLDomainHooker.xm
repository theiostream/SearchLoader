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

#include <signal.h>

#import <SearchLoader/TLLibrary.h>
#define kTLExtendedQueryingKey @"TLExtendedQuerying"
#define kTLInternetQueryingKey @"TLInternetQuerying"
#define kTLLoadingBundlesKey @"TLLoadingBundles"
#define kTLAppIndexerInitKey @"TLAppIndexerInit"

#define kTLDefaultSearchBundleDirectory @"/System/Library/SearchBundles/"
#define kTLCustomSearchBundleDirectory @"/Library/SearchLoader/SearchBundles/"
#define kTLInternalOS6SearchBundleDirectory @"/Library/SearchLoader/Internal/OS6/"

#define TLFileExists(file) [[NSFileManager defaultManager] fileExistsAtPath: file ]

extern "C" NSArray *SPGetExtendedDomains();
extern "C" NSString *SPDisplayIdentifierForDomain(int domain);
extern "C" NSString *SPCategoryForDomain(int domain);

__attribute__((unused))
static NSString *NSStringFromNSRange(NSRange range) {
	return [NSString stringWithFormat:@"(%lu, %lu)", (unsigned long)range.location, (unsigned long)range.length];
}

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
	UIImage *padImage = TLConstructorIsPad() ? [%c(UIImage) imageWithContentsOfFile:[NSString stringWithFormat:@"/Library/SearchLoader/Missing/Pad/%@.png", displayID]] : nil;
	return padImage ?: [%c(UIImage) imageWithContentsOfFile:[NSString stringWithFormat:@"/Library/SearchLoader/Missing/%@.png", displayID]];
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
	[[%c(UIApplication) sharedApplication] setNetworkActivityIndicatorVisible:(state != 0)];
}

// ------

// Global

// TODO: Now we don't need whole bundles, just plists (for this)
// TODO: Investigate hooking SPAllDomainsVector.
MSHook(NSArray *, SPGetExtendedDomains) {
	NSMutableArray *ret = [NSMutableArray arrayWithArray:_SPGetExtendedDomains()];
	NSMutableArray *internet = [NSMutableArray array];
	
	TLIterateExtensions(^(NSString *path){
		NSBundle *bundle = [NSBundle bundleWithPath:path];
		NSDictionary *info = [bundle infoDictionary];
		NSString *displayID = [info objectForKey:@"SPDisplayIdentifier"];
		
		// SBSCopyBundlePathForDisplayIdentifier freezes. We may need a new thread here or something.
		/*NSString *(*SBSCopyBundlePathForDisplayIdentifier)(NSString *) = (NSString *(*)(NSString *))dlsym(RTLD_DEFAULT, "SBSCopyBundlePathForDisplayIdentifier");
		if (!(*SBSCopyBundlePathForDisplayIdentifier)(displayID)) {
			if (![[info objectForKey:@"TLForceAppForSpotlightPlus"] boolValue]) continue;
			if (!TLHasSpotlightPlus()) continue;
		}*/
		
		if ([[info objectForKey:@"TLIsSearchBundle"] boolValue]) {
			if (TLIsInProcess("AppIndexer")) return;
		}

		NSMutableDictionary *dict = [NSMutableDictionary dictionary];
		[dict setObject:displayID forKey:@"SPDisplayIdentifier"];
		[dict setObject:[info objectForKey:@"SPCategory"] forKey:@"SPCategory"];
		if ([info objectForKey:@"SPRequiredCapabilities"]) [dict setObject:[info objectForKey:@"SPRequiredCapabilities"] forKey:@"SPRequiredCapabilities"];
		if ([info objectForKey:@"TLDisplayName"]) [dict setObject:[info objectForKey:@"TLDisplayName"] forKey:@"TLDisplayName"];
		if (TLGetThreadKey(kTLExtendedQueryingKey) && [info objectForKey:@"TLIsSearchBundle"]) [dict setObject:[info objectForKey:@"TLIsSearchBundle"] forKey:@"TLIsSearchBundle"];

		NSMutableArray *tgt = [[info objectForKey:@"TLUsesInternet"] boolValue] ? internet : ret;
		[tgt addObject:dict];
	});
	
	[ret addObjectsFromArray:internet];
	
	return ret;
}

// TODO: Support Localization.
MSHook(NSString *, SPDisplayNameForExtendedDomain, int domain) {
	NSString *category = SPCategoryForDomain(domain);

	NSString *ret = _SPDisplayNameForExtendedDomain(domain);
	if ([ret isEqualToString:category] || (kCFCoreFoundationVersionNumber>=800 && ret==nil)) {
		NSArray *extendedDomains = SPGetExtendedDomains();

		for (NSDictionary *dom in extendedDomains) {
			if ([[dom objectForKey:@"SPDisplayIdentifier"] isEqualToString:SPDisplayIdentifierForDomain(domain)] && [[dom objectForKey:@"SPCategory"] isEqualToString:category]) {
				ret = [dom objectForKey:@"TLDisplayName"] ?: ret;
			}
		}
	}

	return ret;
}

// SpringBoard

// there is a reason for this.
%group TLSpringBoardHooks
%hook SBSearchModel
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

- (void)searchDaemonQueryCompleted:(id)query {
	TLSetThreadKey(kTLInternetQueryingKey, NO); // So we don't end up in shit because of shitty developers.
	[[%c(UIApplication) sharedApplication] setNetworkActivityIndicatorVisible:NO];

	%orig;
}

- (NSURL *)launchingURLForResult:(SPSearchResult *)result withDisplayIdentifier:(NSString *)displayID andSection:(SPSearchResultSection *)section {
	NSString *url = [result url];
	
	__block NSURL *ret = nil;
	TLIterateExtensions(^(NSString *path){
		NSDictionary *infoDictionary = [[NSBundle bundleWithPath:path] infoDictionary];
		if ([[infoDictionary objectForKey:@"SPDisplayIdentifier"] isEqualToString:displayID]) {
			if ([[infoDictionary objectForKey:@"TLCorrectURL"] boolValue]) {
				NSRange startRange;
				NSRange endRange;
				NSRange targetRange;
				
				BOOL startZero = [[infoDictionary objectForKey:@"TLCorrectURLStartZero"] boolValue];
				BOOL endLength = [[infoDictionary objectForKey:@"TLCorrectURLEndLength"] boolValue];
				
				if (!startZero) {
					NSString *start = [infoDictionary objectForKey:@"TLCorrectURLStartDelimiter"];
					if (start == nil) return;

					startRange = [url rangeOfString:start];
					if (startRange.location == NSNotFound) return;
				}
				else startRange = NSMakeRange(0, 0);

				if (!endLength) {
					NSString *end = [infoDictionary objectForKey:@"TLCorrectURLEndDelimiter"];
					if (end == nil) return;

					NSRange searchRange = NSMakeRange(startRange.location + startRange.length, [url length] - (startRange.location + startRange.length));
					endRange = [url rangeOfString:end options:kNilOptions range:searchRange];
					if (endRange.location == NSNotFound) return;
				}
				else endRange = NSMakeRange([url length], 0);
				
				targetRange = NSMakeRange(startRange.location + startRange.length, endRange.location - (startRange.location + startRange.length));
				NSString *vital = [url substringWithRange:targetRange];
				
				NSString *format = [infoDictionary objectForKey:@"TLCorrectURLFormat"];
				if (format == nil) format = @"search://<$ID$>/<$C$>/%@";

				// Format: %@ is the extracted string.
				//	   <$ID$>: display ID
				//	   <$C$>: category
				//	   <$D$>: domain
				
				format = [format stringByReplacingOccurrencesOfString:@"<$ID$>" withString:displayID];
				format = [format stringByReplacingOccurrencesOfString:@"<$C$>" withString:[infoDictionary objectForKey:@"SPCategory"]];
				format = [format stringByReplacingOccurrencesOfString:@"<$D$>" withString:[NSString stringWithFormat:@"%u", [section domain]]];
				
				NSString *corrected = [NSString stringWithFormat:format, vital];
				ret = [NSURL URLWithString:corrected];
			}

			return;
		}
	});

	return ret ?: %orig;
}
%end
%end

%hook SBSearchModel
%group TLOS5SpringBoardHooks
// Let's hope this works.
- (BOOL)_shouldDisplayWebSearchResults {
	NSLog(@"-[SBSearchModel _shouldDisplayWebResults]: (Internet) %d", TLGetThreadKey(kTLInternetQueryingKey));
	return %orig || TLGetThreadKey(kTLInternetQueryingKey);
}

- (UIImage *)imageForDomain:(NSInteger)domain andDisplayID:(NSString *)displayID {
	UIImage *img = TLPadImageForDisplayID(displayID);
	return %orig ?: img;
}
%end

%group TLOS6SpringBoardHooks
- (UIImage *)_imageForDomain:(NSInteger)domain andDisplayID:(NSString *)displayID {
	UIImage *img = TLPadImageForDisplayID(displayID);
	
	if (TLConstructorIsPad() && [displayID isEqualToString:@"com.apple.weather"]) return img;
	return %orig ?: img;
}
%end

%group TLPadOS5SpringBoardHooks
%end

%group TLPadOS6SpringBoardHooks
%end
%end

%group TLOS7SpringBoardHooks
%hook SBSearchViewController
- (BOOL)_shouldDisplayImagesForDomain:(NSInteger)domain {
	__block BOOL ret = %orig;
	
	TLIterateExtensions(^(NSString *path){
		NSDictionary *infoDictionary = [[NSBundle bundleWithPath:path] infoDictionary];
		if (TLDomain([infoDictionary objectForKey:@"SPDisplayIdentifier"], [infoDictionary objectForKey:@"SPCategory"]) == domain) {
			ret = ret || [[infoDictionary objectForKey:@"TLImageResults"] boolValue];
		}
	});

	return ret;
}
%end
%end

/*
related to _imageForResult:
%hook SBSearchViewController
- (BOOL)_shouldDisplayImagesForDomain:(int)domain {
	return %orig;
}
%end*/

// searchd

/* This hook took me 3 days */
%group TLExtendedHooks
%hook SPExtendedDatastore
- (NSArray *)searchDomains {
	TLSetThreadKey(kTLExtendedQueryingKey, YES);
	NSArray *extendedDomains = SPGetExtendedDomains();
	TLSetThreadKey(kTLExtendedQueryingKey, NO);
	
	NSMutableArray *ret = [NSMutableArray array];

	unsigned int iterator = kTLExtendedIndexingStart; // dude i honestly fucking hate keeping this hardcoded amount.
	for (unsigned int i=0; i<[extendedDomains count]; i++) {
		if (![[[extendedDomains objectAtIndex:i] objectForKey:@"TLIsSearchBundle"] boolValue])
			[ret addObject:[NSNumber numberWithUnsignedInt:iterator]];

		iterator++;
	}
	
	return ret;
}
%end
%end

%group TLSearchdHooks
// There could be better solutions for this, which don't involve array iteration every time.
// TODO: IMPLEMENT THIS
/*%hook SPContentIndexer
- (void)_openOrCreateIndex {
	TLSetThreadKey(kTLExtendedQueryingKey, YES);
	NSArray *domains = SPGetExtendedDomains();
	TLSetThreadKey(kTLExtendedQueryingKey, NO);

	__block BOOL shouldStop = NO;
	[domains enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
		if ([[(NSDictionary *)obj objectForKey:@"SPDisplayIdentifier"] isEqualToString:MSHookIvar<NSString *>(self, "_displayIdentifier")] &&
		    [[(NSDictionary *)obj objectForKey:@"SPCategory"] isEqualToString:MSHookIvar<NSString *>(self, "_category")]) {
		    	if ([[(NSDictionary *)obj objectForKey:@"TLIsSearchBundle"] boolValue]) {
				shouldStop = YES;
				*stop = YES;
			}
		}
	}];

	if (shouldStop) return;
	%orig;
}
%end*/

%hook SPContentIndexer
- (void)beginSearch:(NSString *)search {
	__block BOOL performSearch = YES;
	TLIterateExtensions(^(NSString *path){
		NSDictionary *infoDictionary = [[NSBundle bundleWithPath:path] infoDictionary];
		if ([[infoDictionary objectForKey:@"SPDisplayIdentifier"] isEqualToString:MSHookIvar<NSString *>(self, "_displayIdentifier")] && ![[infoDictionary objectForKey:@"TLIsSearchBundle"] boolValue]) {
			if ([search length] < [[infoDictionary objectForKey:@"TLQueryLengthMinimum"] unsignedIntegerValue]) {
				performSearch = NO;
			}
			
			return;
		}
	});

	if (performSearch) %orig;
	else [self cancelSearch];
}
%end

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

		return [system arrayByAddingObjectsFromArray:custom];
	}
	
	return %orig;
}
%end

%hook NSBundle
- (NSBundle *)initWithPath:(NSString *)path {
	if (TLGetThreadKey(kTLLoadingBundlesKey)) {
		NSBundle *bundle = %orig;
		if (bundle == nil && ([path hasPrefix:kTLDefaultSearchBundleDirectory])) {
			NSString *bundlename = [path substringFromIndex:[kTLDefaultSearchBundleDirectory length]];

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
	NSLog(@"[SearchLoader] Query being cancelled.");

	TLSetThreadKey(kTLExtendedQueryingKey, NO);
	%orig;

	// Inform datastores.
	NSArray *datastores = [[SPBundleManager sharedManager] datastores];

	for (NSObject<TLSearchDatastore> *datastore in datastores) {
		if ([datastore respondsToSelector:@selector(searchClientDidCancelQuery)])
			[datastore searchClientDidCancelQuery];
	}
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
		MSHookFunction(MSFindSymbol(MSGetImageByName("/System/Library/PrivateFrameworks/Search.framework/Search"), "_SPGetExtendedDomains"), MSHake(SPGetExtendedDomains));
		
		const char *displayNameSymbol = kCFCoreFoundationVersionNumber>=800 ? "_SPDisplayNameForDomain" : "_SPDisplayNameForExtendedDomain";
		MSHookFunction(MSFindSymbol(MSGetImageByName("/System/Library/PrivateFrameworks/Search.framework/Search"), displayNameSymbol), MSHake(SPDisplayNameForExtendedDomain));
		
		$processedSearchBundle = YES;
	}

	return ret;
}
%end
%end

// AppIndexer

%group TLAppIndexerHooks
%hook AppIndexer
- (id)initWithDisplayID:(NSString *)displayID andCategory:(NSString *)category {
	// Technically this isn't needed because SBSCopyBundlePathForDisplayIdentifier() is only called on that occurence.
	TLSetThreadKey(kTLAppIndexerInitKey, YES);
	self = %orig;
	TLSetThreadKey(kTLAppIndexerInitKey, NO);

	return self;
}
%end
%end

MSHook(NSString *, SBSCopyBundlePathForDisplayIdentifier, NSString *displayIdentifier) {
	__block NSString *bundlePath = _SBSCopyBundlePathForDisplayIdentifier(displayIdentifier);
	if (TLGetThreadKey(kTLAppIndexerInitKey) && [[[NSBundle bundleWithPath:bundlePath] infoDictionary] objectForKey:@"SPSearchBundle"] == nil) {
		[bundlePath release];

		TLIterateExtensions(^(NSString *path){
			if ([[[[NSBundle bundleWithPath:path] infoDictionary] objectForKey:@"SPDisplayIdentifier"] isEqualToString:displayIdentifier]) {
				bundlePath = [path retain];
				return;
			}
		});
	}

	return bundlePath;
}

/*%hook SPContentResult
+ (id)resultWithRecord:(id)record domain:(int)domain displayIdentifier:(NSString *)displayIdentifier query:(NSString *)query {
	%log;
	return %orig;
}
%end*/

// Constructor

%ctor {
	NSLog(@"[SearchLoader] In Soviet Russia, burgers eat YOU!");
	
	// Preferences is special.
	if ([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.Preferences"]) {
		%init(TLPreferencesHooks);
		return;
	}
	
	%init; // DEBUG. Nothing is actually inside _ungrouped.
	MSHookFunction(MSFindSymbol(MSGetImageByName("/System/Library/PrivateFrameworks/Search.framework/Search"), "_SPGetExtendedDomains"), MSHake(SPGetExtendedDomains));
	
	const char *displayNameSymbol = kCFCoreFoundationVersionNumber>=800 ? "_SPDisplayNameForDomain" : "_SPDisplayNameForExtendedDomain";
	MSHookFunction(MSFindSymbol(MSGetImageByName("/System/Library/PrivateFrameworks/Search.framework/Search"), displayNameSymbol), MSHake(SPDisplayNameForExtendedDomain));
	
	if ([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) {
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, &_TLSetNeedsInternet, CFSTR("am.theiostre.searchloader.INTERNALNET"), NULL, 0);
		%init(TLSpringBoardHooks);
		
		if (kCFCoreFoundationVersionNumber >= 800) {
			%init(TLOS7SpringBoardHooks);
		}
		else if (TLIsOS6) {
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

	else if (TLIsInProcess("AppIndexer")) {
		MSHookFunction(MSFindSymbol(NULL, "_SBSCopyBundlePathForDisplayIdentifier"), MSHake(SBSCopyBundlePathForDisplayIdentifier));
		%init(TLAppIndexerHooks);
	}
}

