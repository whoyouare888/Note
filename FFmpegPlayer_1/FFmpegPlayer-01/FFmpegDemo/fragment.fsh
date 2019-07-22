precision mediump float;

varying lowp vec2 varyTextCoord;

uniform sampler2D texture_y;
uniform sampler2D texture_u;
uniform sampler2D texture_v;

void main()
{
    float y = texture2D(texture_y, varyTextCoord).r;
    float u = texture2D(texture_u, varyTextCoord).r - 0.5;
    float v = texture2D(texture_v, varyTextCoord).r - 0.5;

    float r = y + 1.402 * v;
    float g = y - 0.344 * u - 0.714 * v;
    float b = y + 1.772 * u;
    
    gl_FragColor = vec4(r, g, b, 1.0);
}
