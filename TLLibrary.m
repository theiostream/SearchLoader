#import <SearchLoader/TLLibraryInternal.h>
#include <objc/runtime.h>
#include <dlfcn.h>
#include <notify.h>

// check out SPSearchDomainForDisplayIdentifierAndCategory
NSInteger TLDomain(NSString *displayID, NSString *category) {
	NSArray *(*SPGetExtendedDomains)(void) = (NSArray *(*)(void))dlsym(RTLD_DEFAULT, "SPGetExtendedDomains");
	NSArray *domains = (*SPGetExtendedDomains)();
	
	NSInteger count = 0;
	
	for (NSDictionary *dict in domains) {
		if ([[dict objectForKey:@"SPDisplayIdentifier"] isEqualToString:displayID] &&
			[[dict objectForKey:@"SPCategory"] isEqualToString:category]) {
			return kTLExtendedIndexingStart + count;
		}
		
		count++;
	}
	
	[NSException raise:@"TLInvalidDomainRequestException" format:@"There is no such extended domain registered as requested. (DisplayID: %@; Category: %@).", displayID, category];
	return -1;
}

void TLCommitResults(NSArray *results, NSInteger domain, SDSearchQuery *pipe) {
	if (TLIsOS6) [pipe appendResults:results toSerializerDomain:domain];
	else {
		for (SPSearchResult *result in results) {
			[result setDomain:domain];
		}
		
		[pipe appendResults:results];
	}
}

// Passed-in is SPDisplayIdentifier
void TLOpenSearchResult(NSString *displayID, NSString *category, unsigned long long identifier) {
	NSURL *searchURL = [NSURL URLWithDisplayIdentifier:displayID forSearchResultDomain:TLDomain(displayID, category) andIdentifier:identifier];
	Class $UIApplication = objc_getClass("UIApplication");
	if (objc_getClass("SpringBoard"))
		[(SpringBoard *)[$UIApplication sharedApplication] applicationOpenURL:searchURL publicURLsOnly:NO];
	else
		[[$UIApplication sharedApplication] openURL:searchURL];
}

BOOL TLRequestRecordUpdatesArray(NSString *displayID, NSString *category, NSArray *IDs) {
	SPDaemonConnection *conn = [objc_getClass("SPDaemonConnection") sharedConnection];
	if (![conn startRecordUpdatesForApplication:displayID andCategory:category]) return NO;
	if (![conn requestRecordUpdatesForApplication:displayID category:category andIDs:IDs]) return NO;
	if (![conn endRecordUpdatesForApplication:displayID andCategory:category]) return NO;
	
	return YES;
}

BOOL TLRequestRecordUpdates(NSString *displayID, NSString *category, SPSearchQuery *query) {
	return TLRequestRecordUpdatesArray(displayID, category, [NSArray arrayWithObject:[query searchString]]);
}

void TLRequireInternet(BOOL required) {
	int token;
	
	notify_register_check("am.theiostre.searchloader.INTERNALNET", &token);
	notify_set_state(token, required);
	notify_cancel(token);
	
	notify_post("am.theiostre.searchloader.INTERNALNET");
}
