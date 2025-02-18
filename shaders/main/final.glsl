/// ------------------------------------- /// Vertex Shader /// ------------------------------------- ///

#ifdef VERTEX
    out vec2 screenCoord;

    void main(){
        gl_Position = ftransform();
        screenCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    }
#endif

/// ------------------------------------- /// Fragment Shader /// ------------------------------------- ///

#ifdef FRAGMENT
    in vec2 screenCoord;

    /* Buffer settings */

    /*
    const int gcolorFormat = R11F_G11F_B10F;
    const int colortex1Format = RGB16_SNORM;
    const int colortex2Format = RGBA8;
    const int colortex3Format = RGB8;
    const int colortex4Format = R11F_G11F_B10F;
    const int colortex5Format = RGBA16F;
    */

    uniform sampler2D gcolor;

    // For Optifine to detect
    #ifdef SHARPEN_FILTER
    #endif

    #if (ANTI_ALIASING != 0 && defined SHARPEN_FILTER) || defined CHROMATIC_ABERRATION || defined RETRO_FILTER
        uniform float viewWidth;
        uniform float viewHeight;
    #endif

    #if ANTI_ALIASING != 0 && defined SHARPEN_FILTER
        // https://www.shadertoy.com/view/lslGRr
        vec3 sharpenFilter(vec3 color, vec2 texCoord){
            vec2 pixSize = 1.0 / vec2(viewWidth, viewHeight);

            vec2 topRightCorner = texCoord + pixSize;
            vec2 bottomLeftCorner = texCoord - pixSize;

            vec3 blur = texture2DLod(gcolor, bottomLeftCorner, 0).rgb + texture2DLod(gcolor, topRightCorner, 0).rgb +
                texture2DLod(gcolor, vec2(bottomLeftCorner.x, topRightCorner.y), 0).rgb + texture2DLod(gcolor, vec2(topRightCorner.x, bottomLeftCorner.y), 0).rgb;
            
            return color * 2.0 - blur * 0.25;
        }
    #endif

    void main(){
        #ifdef RETRO_FILTER
            vec2 retroResolution = vec2(viewWidth, viewHeight) * 0.5 / MC_RENDER_QUALITY;
            vec2 retroCoord = floor(screenCoord * retroResolution) / retroResolution;

            #define screenCoord retroCoord
        #endif

        #ifdef CHROMATIC_ABERRATION
            vec2 chromaStrength = ((screenCoord - 0.5) * ABERRATION_PIX_SIZE) / vec2(viewWidth, viewHeight);

            vec3 color = vec3(texture2DLod(gcolor, screenCoord - chromaStrength, 0).r,
                texture2DLod(gcolor, screenCoord, 0).g,
                texture2DLod(gcolor, screenCoord + chromaStrength, 0).b);
        #else
            vec3 color = texture2DLod(gcolor, screenCoord, 0).rgb;
        #endif

        #if ANTI_ALIASING != 0 && defined SHARPEN_FILTER
            color = sharpenFilter(color, screenCoord);
        #endif

        gl_FragColor = vec4(color, 1);
    }
#endif