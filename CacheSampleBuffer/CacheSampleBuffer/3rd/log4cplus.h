
#include <syslog.h>
#ifndef XDX_IOS
#define XDX_IOS
#endif

#pragma - Please select your log mode and log level

// Note: Only debug mode will print log. You could also set mode for log level.
#define kXDXDebugMode
// XDXLogLevelFatal , XDXLogLevelError , XDXLogLevelWarn , XDXLogLevelInfo , XDXLogLevelDebug
#define XDXLogLevelDebug

#pragma ----------------------------------

#ifdef kXDXDebugMode

static const int XDX_IOS_FLAG_FATAL = 0x10;
static const int XDX_IOS_FLAG_ERROR = 0x08;
static const int XDX_IOS_FLAG_WARN  = 0x04;
static const int XDX_IOS_FLAG_INFO  = 0x02;
static const int XDX_IOS_FLAG_DEBUG = 0x01;

#ifdef XDXLogLevelFatal
static const int XDX_IOS_LOG_LEVEL = XDX_IOS_FLAG_FATAL;
#elif defined(XDXLogLevelError)
static const int XDX_IOS_LOG_LEVEL = (XDX_IOS_FLAG_FATAL | XDX_IOS_FLAG_ERROR);
#elif defined(XDXLogLevelWarn)
static const int XDX_IOS_LOG_LEVEL = (XDX_IOS_FLAG_FATAL | XDX_IOS_FLAG_ERROR | XDX_IOS_FLAG_WARN);
#elif defined(XDXLogLevelInfo)
static const int XDX_IOS_LOG_LEVEL = (XDX_IOS_FLAG_FATAL | XDX_IOS_FLAG_ERROR | XDX_IOS_FLAG_WARN | XDX_IOS_FLAG_INFO);
#elif defined(XDXLogLevelDebug)
static const int XDX_IOS_LOG_LEVEL = (XDX_IOS_FLAG_FATAL | XDX_IOS_FLAG_ERROR | XDX_IOS_FLAG_WARN | XDX_IOS_FLAG_INFO | XDX_IOS_FLAG_DEBUG);
#endif



#define log4cplus_fatal(category, logFmt, ...) \
if(XDX_IOS_LOG_LEVEL & XDX_IOS_FLAG_FATAL) \
syslog(LOG_CRIT, "%s:" logFmt, category,##__VA_ARGS__); \

#define log4cplus_error(category, logFmt, ...) \
if(XDX_IOS_LOG_LEVEL & XDX_IOS_FLAG_ERROR) \
syslog(LOG_ERR, "%s:" logFmt, category,##__VA_ARGS__); \

#define log4cplus_warn(category, logFmt, ...) \
if(XDX_IOS_LOG_LEVEL & XDX_IOS_FLAG_WARN) \
syslog(LOG_WARNING, "%s:" logFmt, category,##__VA_ARGS__); \

#define log4cplus_info(category, logFmt, ...) \
if(XDX_IOS_LOG_LEVEL & XDX_IOS_FLAG_INFO) \
syslog(LOG_WARNING, "%s:" logFmt, category,##__VA_ARGS__); \

#define log4cplus_debug(category, logFmt, ...) \
if(XDX_IOS_LOG_LEVEL & XDX_IOS_FLAG_DEBUG) \
syslog(LOG_WARNING, "%s:" logFmt, category,##__VA_ARGS__); \


#else

#define log4cplus_fatal(category, logFmt, ...); \

#define log4cplus_error(category, logFmt, ...); \

#define log4cplus_warn(category, logFmt, ...); \

#define log4cplus_info(category, logFmt, ...); \

#define log4cplus_debug(category, logFmt, ...); \

#endif

