using UnityEditor;
using UnityEngine;

public static class FxStyles
{
    public static readonly GUIStyle Header;
    public static readonly GUIStyle HeaderCheckbox;

    static FxStyles()
    {
        Header = new GUIStyle("ShurikenModuleTitle")
        {
            font = (new GUIStyle("Label")).font,
            border = new RectOffset(15, 7, 4, 4),
            fixedHeight = 22,
            contentOffset = new Vector2(20.0f, -2.0f)
        };

        HeaderCheckbox = new GUIStyle("ShurikenCheckMark");
    }
}