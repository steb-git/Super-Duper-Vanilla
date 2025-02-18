float getOutline(ivec2 iUv, float depthOrigin, int pixSize){
    ivec2 topRightCorner = iUv - pixSize;
    ivec2 bottomLeftCorner = iUv + pixSize;

    float depth0 = toView(texelFetch(depthtex0, topRightCorner, 0).x);
    float depth1 = toView(texelFetch(depthtex0, bottomLeftCorner, 0).x);
    float depth2 = toView(texelFetch(depthtex0, ivec2(topRightCorner.x, bottomLeftCorner.y), 0).x);
    float depth3 = toView(texelFetch(depthtex0, ivec2(bottomLeftCorner.x, topRightCorner.y), 0).x);

    float sumDepth = depth0 + depth1 + depth2 + depth3;

    #if OUTLINES == 1
        // Calculate standard outlines
        return saturate(totalDepth - depthOrigin * 4.0);
    #else
        // Calculate dungeons outlines
        return saturate((depthOrigin * 256.0 - sumDepth * 64.0) / -depthOrigin);
    #endif
}