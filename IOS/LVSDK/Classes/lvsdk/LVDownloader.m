//
//  LVDownloader.m
//  LVSDK
//
//  Created by dongxicheng on 4/14/15.
//  Copyright (c) 2015 dongxicheng. All rights reserved.
//

#import "LVDownloader.h"
#import "LVUtil.h"
#import "LVData.h"
#import "LView.h"

@interface LVDownloader ()
@property(nonatomic,strong) NSData* data;
@property(nonatomic,strong) id strongSelf;
@end


@implementation LVDownloader


static void releaseUserDataDownloader(LVUserDataDownloader* user){
    if( user && user->downloader ){
        LVDownloader* downloader = CFBridgingRelease(user->downloader);
        user->downloader = NULL;
        if( downloader ){
            downloader.userData = nil;
            downloader.lview = nil;
        }
    }
}

-(void) dealloc{
    releaseUserDataDownloader(_userData);
}

-(id) init:(lv_State*) l{
    self = [super init];
    if( self ){
        self.luaObjRetainKey = [[NSMutableString alloc] init];
        self.lview = (__bridge LView *)(l->lView);
        self.strongSelf = self;
    }
    return self;
}


#pragma -mark downloader
static int download (lv_State *L) {
    if( lv_gettop(L)>=2 ) {
        LVDownloader* downloader = [[LVDownloader alloc] init:L];
        NSString* url = lv_paramString(L, 1);     // 1: url
        //NSString* fileName = lvL_paramString(L, 2);// 2: fileName
                                                   // 3: callback
        if( lv_type(L, -1) == LV_TFUNCTION ) {
            [LVUtil registryValue:L key:downloader stack:-1];
        }
        
        {
            NEW_USERDATA(userData, LVUserDataDownloader);
            userData->downloader = CFBridgingRetain(downloader);
            downloader.userData = userData;
            
            lvL_getmetatable(L, META_TABLE_Downloader );
            lv_setmetatable(L, -2);
            
            [LVUtil registryValue:L key:downloader.luaObjRetainKey stack:-1];
        }
        [LVUtil download:url callback:^(NSData *data) {
            downloader.data = data;
            [downloader performSelectorOnMainThread:@selector(didFileLoaded) withObject:nil waitUntilDone:NO];
        }];
        return 1;
    } else {
        LVError(@"downloader( Callback==nil )!!!");
    }
    return 0;
}

-(void) didFileLoaded{
    lv_State* L = self.lview.l;
    if( L ){
        if( self.data ) {
            [LVData createDataObject:L data:self.data];
        } else {
            lv_pushnil(L);
        }
        [LVUtil call:L lightUserData:self key1:nil key2:nil nargs:1 nrets:0];
        
        [LVUtil unregistry:L key:self.luaObjRetainKey];
        [LVUtil unregistry:L key:self];
    }
    self.strongSelf = nil;
}

 static int __gc (lv_State *L) {
    LVUserDataDownloader * user = (LVUserDataDownloader *)lv_touserdata(L, 1);
    releaseUserDataDownloader(user);
    return 0;
}

static int __tostring (lv_State *L) {
    LVUserDataDownloader * user = (LVUserDataDownloader *)lv_touserdata(L, 1);
    if( user ){
        LVDownloader* downloader =  (__bridge LVDownloader *)(user->downloader);
        NSString* s = [NSString stringWithFormat:@"LVUserDataDownloader: %@", downloader ];
        lv_pushstring(L, s.UTF8String);
        return 1;
    }
    return 0;
}

static int PathOfResource (lv_State *L) {
    NSString* fileName = lv_paramString(L, 1);
    NSString* path = [LVUtil cachesPath:fileName];
    lv_pushstring(L, path.UTF8String);
    return 1;
}

+(int) classDefine:(lv_State *)L {
    {
        lv_pushcfunction(L, PathOfResource);
        lv_setglobal(L, "PathOfResource");
    }
    {
        lv_pushcfunction(L, download);
        lv_setglobal(L, "Download");
    }
    const struct lvL_reg memberFunctions [] = {
        {"__gc", __gc },
        
        {"__tostring", __tostring },
        {NULL, NULL}
    };
    
    lv_createClassMetaTable(L, META_TABLE_Downloader);
    
    lvL_openlib(L, NULL, memberFunctions, 0);
    return 1;
}

@end