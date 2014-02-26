/*%%%%
%% TLLibrary.h
%% SearchLoader / Spotlight+
%% Created by Daniel Ferreira on 1/12/2012.
%%%%*/

#ifndef _TLLIBRARY_INTERNAL_H
#define _TLLIBRARY_INTERNAL_H

#import <Foundation/Foundation.h>
#define kTLExtendedIndexingStart 15 // I hate this. Please for god's sake remove this.

#ifndef TLIsOS6
#define TLIsOS6 (kCFCoreFoundationVersionNumber >= 793.00)
#endif

extern NSString *const kSPContentAuxiliarySubtitleKey;
extern NSString *const kSPContentAuxiliaryTitleKey;
extern NSString *const kSPContentCategoryKey;
extern NSString *const kSPContentContentKey;
extern NSString *const kSPContentExternalIDKey;
extern NSString *const kSPContentSubtitleKey;
extern NSString *const kSPContentSummaryKey;
extern NSString *const kSPContentTitleKey;

@interface SPBundleManager : NSObject
+ (id)sharedManager;
- (NSArray *)datastores;
@end

@interface SPSpotlightManager : NSObject
+ (SPSpotlightManager *)sharedManager;
- (void)eraseIndexForApplication:(NSString *)arg1 category:(NSString *)arg2;
- (void)application:(NSString *)arg1 modifiedRecordIDs:(NSArray *)arg2 forCategory:(NSString *)arg3;
@end

@class SDSearchQuery;
@protocol SPSearchDatastore <NSObject>
- (void)performQuery:(SDSearchQuery *)query withResultsPipe:(SDSearchQuery *)results;
- (NSArray *)searchDomains;
- (NSString *)displayIdentifierForDomain:(NSInteger)domain;
@end

@protocol TLSearchDatastore <SPSearchDatastore>
@optional
- (BOOL)blockDatastoreComplete;
- (void)searchClientDidCancelQuery;
@end

@protocol SPSpotlightDatastore <NSObject>
- (NSDictionary *)contentToIndexForID:(NSString *)anId inCategory:(NSString *)category;
- (NSArray *)allIdentifiersInCategory:(NSString *)category;
@end

@interface SPDaemonConnection : NSObject
+ (id)sharedConnection;
- (BOOL)endRecordUpdatesForApplication:(NSString *)arg1 andCategory:(NSString *)arg2;
- (BOOL)requestRecordUpdatesForApplication:(NSString *)arg1 category:(NSString *)arg2 andIDs:(NSArray *)arg3;
- (BOOL)startRecordUpdatesForApplication:(NSString *)arg1 andCategory:(NSString *)arg2;
@end

@interface SPSearchQuery : NSObject <NSCopying>
- (NSArray *)searchDomains;
- (NSString *)searchString;
- (BOOL)cancelled;
- (char *)domainsVector;
- (int)domainsVectorCount;
@end

@interface SDSearchQuery : SPSearchQuery
- (void)appendResults:(NSArray *)results;
- (void)appendResults:(NSArray *)results toSerializerDomain:(NSInteger)domain;
- (void)queryFinishedWithError:(NSError *)error;
- (void)storeCompletedSearch:(NSObject <SPSearchDatastore> *)datastore;
@end

@interface SDActor : SDSearchQuery
@end

@protocol SPSearchResult <NSObject>
- (unsigned long long)identifier;
- (int)domain;
@optional
- (BOOL)getBadgeValue:(float *)arg1;
- (const char *)URLUTF8String;
- (const char *)auxiliarySubtitleUTF8String;
- (const char *)auxiliaryTitleUTF8String;
- (const char *)summaryUTF8String;
- (const char *)subtitleUTF8String;
- (const char *)titleUTF8String;
- (const char *)resultDisplayIdentifierUTF8String;
- (int)resultDomain;
@end

@protocol SPSearchResultCursor <NSObject>
- (void)setBadge:(id)arg1;
- (void)setURL:(id)arg1;
- (void)setIdentifier:(unsigned long long)arg1;
- (void)setAuxiliarySubtitle:(id)arg1;
- (void)setAuxiliaryTitle:(id)arg1;
- (void)setSummary:(id)arg1;
- (void)setSubtitle:(id)arg1;
- (void)setTitle:(id)arg1;
- (void)setResultDisplayIdentifier:(id)arg1;
- (void)setResultDomain:(int)arg1;
- (void)setDomain:(int)arg1;
@end

@interface SPSearchResult : NSObject <SPSearchResult, SPSearchResultCursor>
@property(retain, nonatomic) NSString *url;
@property(retain, nonatomic) NSURL *URL;
@property(nonatomic) unsigned long long identifier;
@property(retain, nonatomic) NSString *auxiliarySubtitle;
@property(retain, nonatomic) NSString *auxiliaryTitle;
@property(retain, nonatomic) NSString *summary;
@property(retain, nonatomic) NSString *subtitle;
@property(retain, nonatomic) NSString *title;
@property(copy, nonatomic) NSNumber *badge;
@property(retain, nonatomic) NSString *resultDisplayIdentifier;
@property(nonatomic) int resultDomain;
@property(nonatomic) int domain;
@end

@interface SPSearchResultSection : NSObject
- (unsigned int)domain;
- (NSString *)category;
- (NSString *)displayIdentifier;
@end

@interface SPContentIndexer : NSObject
+ (id)indexerForDisplayIdentifier:(id)arg1 category:(id)arg2;
- (void)clearIndex;
- (void)cancelSearch;
@end

@interface SPRecord : NSObject
@property(retain, nonatomic) NSString *actionURL; // @dynamic actionURL;
@property(retain, nonatomic) NSString *auxsubtitle; // @dynamic auxsubtitle;
@property(retain, nonatomic) NSString *auxtitle; // @dynamic auxtitle;
@property(retain, nonatomic) NSString *content; // @dynamic content;
@property(retain, nonatomic) NSNumber *cxid; // @dynamic cxid;
@property(retain, nonatomic) NSDate *date; // @dynamic date;
@property(retain, nonatomic) NSString *extid; // @dynamic extid;
@property(retain, nonatomic) NSNumber *generation; // @dynamic generation;
@property(retain, nonatomic) NSString *subtitle; // @dynamic subtitle;
@property(retain, nonatomic) NSString *summary; // @dynamic summary;
@property(retain, nonatomic) NSString *title; // @dynamic title;
@end

@interface NSURL (TLSearchAdditions)
+ (NSURL *)URLWithDisplayIdentifier:(NSString *)arg1 forSearchResultDomain:(NSInteger)arg2 andIdentifier:(unsigned long long)arg3;
@end

@interface SpringBoard : UIApplication
- (void)applicationOpenURL:(NSURL *)url publicURLsOnly:(BOOL)pub;
@end

#define kTLDisplayIDKey @"display_id"
#define kTLCategoryKey @"category"

#endif /* _TLLIBRARY_INTERNAL_H */
