#ifndef EGL_HELPERS_H
#define EGL_HELPERS_H

#include <epoxy/gl.h>
#ifdef __APPLE__
// On macOS, since EGL is not natively available,
// define stub types and constants.
typedef void *EGLDisplay;
typedef void *EGLConfig;
typedef void *EGLContext;
typedef void *EGLNativeWindowType;
typedef void *EGLSurface;
typedef int EGLint;
typedef int EGLBoolean;  // Added typedef for EGLBoolean

#    define EGL_FALSE 0
#    define EGL_TRUE 1
#    define EGL_NO_DISPLAY ((EGLDisplay)0)  // Added EGL_NO_DISPLAY definition
#    define EGL_NO_SURFACE ((EGLSurface)0)
#    define EGL_NO_CONTEXT ((EGLContext)0)
#    define EGL_SUCCESS 0
#    define EGL_NOT_INITIALIZED 0x3001

// Standard EGL error codes.
#    ifndef EGL_BAD_ACCESS
#        define EGL_BAD_ACCESS 0x3002
#    endif
#    ifndef EGL_BAD_ALLOC
#        define EGL_BAD_ALLOC 0x3003
#    endif
#    ifndef EGL_BAD_ATTRIBUTE
#        define EGL_BAD_ATTRIBUTE 0x3004
#    endif
#    ifndef EGL_BAD_CONFIG
#        define EGL_BAD_CONFIG 0x3005
#    endif
#    ifndef EGL_BAD_CONTEXT
#        define EGL_BAD_CONTEXT 0x3006
#    endif
#    ifndef EGL_BAD_CURRENT_SURFACE
#        define EGL_BAD_CURRENT_SURFACE 0x3007
#    endif
#    ifndef EGL_BAD_DISPLAY
#        define EGL_BAD_DISPLAY 0x3008
#    endif
#    ifndef EGL_BAD_MATCH
#        define EGL_BAD_MATCH 0x3009
#    endif
#    ifndef EGL_BAD_NATIVE_PIXMAP
#        define EGL_BAD_NATIVE_PIXMAP 0x300A
#    endif
#    ifndef EGL_BAD_NATIVE_WINDOW
#        define EGL_BAD_NATIVE_WINDOW 0x300B
#    endif
#    ifndef EGL_BAD_PARAMETER
#        define EGL_BAD_PARAMETER 0x300C
#    endif
#    ifndef EGL_BAD_SURFACE
#        define EGL_BAD_SURFACE 0x300D
#    endif
#    ifndef EGL_CONTEXT_LOST
#        define EGL_CONTEXT_LOST 0x300E
#    endif

// Constants for context creation.
#    define EGL_CONTEXT_CLIENT_VERSION 0x3098
#    define EGL_CONTEXT_MINOR_VERSION_KHR 0x30FB
#    define EGL_CONTEXT_OPENGL_PROFILE_MASK 0x30FD
#    define EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT 0x00000001
#    define EGL_NONE 0x3038

// Provide stub implementations for EGL functions.
static inline EGLint eglMakeCurrent(EGLDisplay dpy,
                                    EGLSurface draw,
                                    EGLSurface read,
                                    EGLContext ctx)
{
    // Stub: return success.
    return EGL_TRUE;
}

static inline EGLint eglGetError(void)
{
    // Stub: no errors.
    return EGL_SUCCESS;
}

static inline EGLContext eglCreateContext(EGLDisplay dpy,
                                          EGLConfig config,
                                          EGLContext share_context,
                                          const EGLint *attrib_list)
{
    // Stub: return null context.
    return EGL_NO_CONTEXT;
}

static inline EGLContext eglGetCurrentContext(void)
{
    // Stub: return null context.
    return EGL_NO_CONTEXT;
}

static inline EGLint eglDestroyContext(EGLDisplay dpy, EGLContext ctx)
{
    // Stub: return success.
    return EGL_SUCCESS;
}

// Stub for eglCreateWindowSurface.
static inline EGLSurface eglCreateWindowSurface(EGLDisplay dpy,
                                                EGLConfig config,
                                                EGLNativeWindowType win,
                                                const EGLint *attrib_list)
{
    // Stub: since window surfaces are not used on macOS, return no surface.
    return EGL_NO_SURFACE;
}

// Updated stub for epoxy_has_egl_extension accepting two arguments.
// The display parameter is ignored.
static inline bool epoxy_has_egl_extension(EGLDisplay dpy, const char *extension)
{
    (void)dpy;        // suppress unused parameter warning
    (void)extension;  // suppress unused parameter warning
    return false;
}

#else
#    ifdef CONFIG_EGL
#        include <epoxy/egl.h>
#    else
typedef int EGLConfig;
typedef int EGLContext;
typedef int EGLDisplay;
typedef int EGLNativeWindowType;
typedef int EGLSurface;
typedef int EGLint;
typedef int EGLBoolean;
#    endif
#endif

#ifdef CONFIG_GBM
#    include <gbm.h>
#endif

#include "ui/console.h"
#include "ui/shader.h"

extern EGLDisplay *qemu_egl_display;
extern EGLConfig qemu_egl_config;
extern DisplayGLMode qemu_egl_mode;
extern bool qemu_egl_angle_d3d;

typedef struct egl_fb
{
    int width;
    int height;
    GLuint texture;
    GLuint framebuffer;
    bool delete_texture;
    QemuDmaBuf *dmabuf;
} egl_fb;

#define EGL_FB_INIT \
    {               \
        0,          \
    }

void egl_fb_destroy(egl_fb *fb);
void egl_fb_setup_default(egl_fb *fb, int width, int height);
void egl_fb_setup_for_tex(egl_fb *fb, int width, int height, GLuint texture, bool delete);
void egl_fb_setup_new_tex(egl_fb *fb, int width, int height);
void egl_fb_blit(egl_fb *dst, egl_fb *src, bool flip);
void egl_fb_read(DisplaySurface *dst, egl_fb *src);
void egl_fb_read_rect(DisplaySurface *dst, egl_fb *src, int x, int y, int w, int h);

void egl_texture_blit(QemuGLShader *gls, egl_fb *dst, egl_fb *src, bool flip);
void egl_texture_blend(QemuGLShader *gls,
                       egl_fb *dst,
                       egl_fb *src,
                       bool flip,
                       int x,
                       int y,
                       double scale_x,
                       double scale_y);

extern EGLContext qemu_egl_rn_ctx;

#ifdef CONFIG_GBM
extern int qemu_egl_rn_fd;
extern struct gbm_device *qemu_egl_rn_gbm_dev;

int egl_rendernode_init(const char *rendernode, DisplayGLMode mode);
int egl_get_fd_for_texture(uint32_t tex_id, EGLint *stride, EGLint *fourcc, EGLuint64KHR *modifier);

void egl_dmabuf_import_texture(QemuDmaBuf *dmabuf);
void egl_dmabuf_release_texture(QemuDmaBuf *dmabuf);
void egl_dmabuf_create_sync(QemuDmaBuf *dmabuf);
void egl_dmabuf_create_fence(QemuDmaBuf *dmabuf);
#endif

EGLSurface qemu_egl_init_surface_x11(EGLContext ectx, EGLNativeWindowType win);

#if defined(CONFIG_X11) || defined(CONFIG_GBM)
int qemu_egl_init_dpy_x11(EGLNativeDisplayType dpy, DisplayGLMode mode);
int qemu_egl_init_dpy_mesa(EGLNativeDisplayType dpy, DisplayGLMode mode);
#endif

#ifdef WIN32
int qemu_egl_init_dpy_win32(EGLNativeDisplayType dpy, DisplayGLMode mode);
#endif

EGLContext qemu_egl_init_ctx(void);
bool egl_init(const char *rendernode, DisplayGLMode mode, Error **errp);
bool qemu_egl_has_dmabuf(void);
const char *qemu_egl_get_error_string(void);

#endif /* EGL_HELPERS_H */