varying lowp vec2 varyTextCoord;

uniform sampler2D texture0;

void main()
{
    gl_FragColor = texture2D(texture0, varyTextCoord);
}
