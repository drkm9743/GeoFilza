//
//  GeoFilza18-Bridging-Header.h
//  GeoFilza18
//
//  Read-only file manager for iOS 18.6.2 using darksword kexploit
//

#import <Foundation/Foundation.h>
#import "darksword.h"
#import "utils.h"
#import "kfs.h"

bool setkernproc(NSString *path);
bool dlkerncache(void);
uint64_t getkernproc(void);
bool haskernproc(void);
NSString *getkerncache(void);
void clearkerncachedata(void);
uint64_t getrootvnodeoffset(void);
