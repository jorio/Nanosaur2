//
// internet.h
//

#ifndef __INTERNET_H
#define __INTERNET_H

void ReadHTTPData_VersionInfo(void);
OSStatus LaunchURL(ConstStr255Param urlStr);
Boolean IsInternetAvailable(void);
OSStatus DownloadURL(const char *urlString);



#endif