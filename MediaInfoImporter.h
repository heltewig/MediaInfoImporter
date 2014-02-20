//
//  MediaInfoImporter.h
//
//  Created by Sebastian Heltewig on 08.08.12.
//

#ifndef MediaInfoImporter_MediaInfoImporter_h
#define MediaInfoImporter_MediaInfoImporter_h

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif
    
    Boolean ImportFile(CFMutableDictionaryRef attributes, CFURLRef urlForFile);
    
#ifdef __cplusplus
}
#endif

#endif
