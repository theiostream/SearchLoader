/*%%%%
%% TLLibrary.h
%% SearchLoader / Spotlight+
%% Created by Daniel Ferreira on 1/12/2012.
%%%%*/

#ifndef _TLLIBRARY_H
#define _TLLIBRARY_H

#import "TLLibraryInternal.h"

#ifdef __cplusplus
extern "C" {
#endif

void TLIterateExtensions(void (^handler)(NSString *));
NSUInteger TLDomain(NSString *displayID, NSString *category);

void TLOpenSearchResult(NSString *displayID, NSString *category, unsigned long long identifier);

BOOL TLRequestRecordUpdatesArray(NSString *displayID, NSString *category, NSArray *array);
BOOL TLRequestRecordUpdates(NSString *displayID, NSString *category, SPSearchQuery *query);

void TLRequireInternet(BOOL req);

void TLCommitResults(NSArray *results, NSInteger domain, SDSearchQuery *pipe);
	
static inline void TLFinishQuery(SDSearchQuery *result) {
	if (!TLIsOS6) [result queryFinishedWithError:nil];
}
	
static inline void TLFinishInternetUsage(BOOL *internet, NSObject<SPSearchDatastore> *self, SDSearchQuery *pipe) {
	if (TLIsOS6) { *internet = NO; [pipe storeCompletedSearch:self]; }
	else { TLRequireInternet(NO); }
}
	
static inline void TLStartInternetUsage(BOOL *internet) {
	if (TLIsOS6) { *internet = YES; }
	else { TLRequireInternet(YES); }
}

#ifdef __cplusplus
}
#endif

#endif /* _TLLIBRARY_H */
