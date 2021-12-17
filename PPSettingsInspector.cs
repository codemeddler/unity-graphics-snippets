using System;
using System.Linq.Expressions;
using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(PPSettings))]
public class PPSettingsInspector : Editor
{
    private SerializedProperty _isBloomGroupExpandedProperty;
    private SerializedProperty _bloomEnabledProperty;
    private SerializedProperty _bloomThresholdProperty;
    private SerializedProperty _bloomIntensityProperty;
    private SerializedProperty _bloomTintProperty;
    private SerializedProperty _bloomPreserveAspectRatioProperty;
    private SerializedProperty _bloomWidthProperty;
    private SerializedProperty _bloomHeightProperty;
    private SerializedProperty _bloomLuminanceVectorProperty;
    private SerializedProperty _bloomSelectedLuminanceVectorTypeProperty;

    private readonly string[] _bloomSizeVariants = {"32", "64", "128"};
    private readonly int[] _bloomSizeVariantInts = {32, 64, 128};
    private int _selectedBloomWidthIndex = -1;
    private int _selectedBloomHeightIndex = -1;

    private LuminanceVectorType _selectedLuminanceVectorType;

    private void OnEnable()
    {
        SetupBloomProperties();
    }

    private void SetupBloomProperties()
    {
        _isBloomGroupExpandedProperty =
            serializedObject.FindProperty(GetMemberName((PPSettings s) => s.bloomExpanded));
        _bloomEnabledProperty = serializedObject.FindProperty(GetMemberName((PPSettings s) => s.bloomEnabled));
        _bloomThresholdProperty =
            serializedObject.FindProperty(GetMemberName((PPSettings s) => s.bloomThreshold));
        _bloomIntensityProperty =
            serializedObject.FindProperty(GetMemberName((PPSettings s) => s.bloomIntensity));
        _bloomTintProperty = serializedObject.FindProperty(GetMemberName((PPSettings s) => s.bloomTint));

        _bloomPreserveAspectRatioProperty =
            serializedObject.FindProperty(GetMemberName((PPSettings s) => s.preserveAspectRatio));

        _bloomWidthProperty =
            serializedObject.FindProperty(GetMemberName((PPSettings s) => s.bloomTextureWidth));
        _selectedBloomWidthIndex = Array.IndexOf(_bloomSizeVariantInts, _bloomWidthProperty.intValue);
        _bloomHeightProperty =
            serializedObject.FindProperty(GetMemberName((PPSettings s) => s.bloomTextureHeight));
        _selectedBloomHeightIndex = Array.IndexOf(_bloomSizeVariantInts, _bloomHeightProperty.intValue);

        _bloomLuminanceVectorProperty =
            serializedObject.FindProperty(GetMemberName((PPSettings s) => s.bloomLuminanceVector));
        _bloomSelectedLuminanceVectorTypeProperty =
            serializedObject.FindProperty(GetMemberName((PPSettings s) => s.bloomLuminanceCalculationType));
        _selectedLuminanceVectorType = (LuminanceVectorType) _bloomSelectedLuminanceVectorTypeProperty.enumValueIndex;
    }

    public override void OnInspectorGUI()
    {
        serializedObject.Update();

        var indent = EditorGUI.indentLevel;

        DrawBloomEditor();
        EditorGUILayout.Space();

        EditorGUI.indentLevel = indent;
        serializedObject.ApplyModifiedProperties();
    }

    private void DrawBloomEditor()
    {
        Header("Bloom", _isBloomGroupExpandedProperty, _bloomEnabledProperty);

        if (!_isBloomGroupExpandedProperty.boolValue) return;
        EditorGUI.indentLevel += 1;

        EditorGUILayout.LabelField("Bloom threshold");
        EditorGUILayout.Slider(_bloomThresholdProperty, 0.0f, 1.0f, "");
        EditorGUILayout.LabelField("Bloom intensity");
        EditorGUILayout.Slider(_bloomIntensityProperty, 0.0f, 15.0f, "");
        EditorGUILayout.LabelField("Bloom tint");
        _bloomTintProperty.colorValue = EditorGUILayout.ColorField("", _bloomTintProperty.colorValue);

        DrawBloomWidthProperties();
        DisplayLuminanceVectorProperties();

        EditorGUI.indentLevel -= 1;
    }

    private void DisplayLuminanceVectorProperties()
    {
        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Bright Pass Luminance calculation");

        _selectedLuminanceVectorType = (LuminanceVectorType) EditorGUILayout.EnumPopup(_selectedLuminanceVectorType);
        _bloomSelectedLuminanceVectorTypeProperty.enumValueIndex = (int) _selectedLuminanceVectorType;
        switch (_selectedLuminanceVectorType)
        {
            case LuminanceVectorType.Custom:
                EditorGUILayout.PropertyField(_bloomLuminanceVectorProperty, new GUIContent(""));
                break;
            case LuminanceVectorType.Uniform:
                const float oneOverThree = 1.0f / 3.0f;
                _bloomLuminanceVectorProperty.vector3Value = new Vector3(oneOverThree, oneOverThree, oneOverThree);
                break;
            case LuminanceVectorType.sRGB:
                _bloomLuminanceVectorProperty.vector3Value = new Vector3(0.2126f, 0.7152f, 0.0722f);
                break;
            default:
                throw new ArgumentOutOfRangeException();
        }

        var vector = _bloomLuminanceVectorProperty.vector3Value;
        if (!Mathf.Approximately(vector.x + vector.y + vector.z, 1f))
        {
            EditorGUILayout.HelpBox("Luminance vector is not normalized.\nVector values should sum up to 1.",
                MessageType.Warning);
        }
    }

    private void DrawBloomWidthProperties()
    {
        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Bloom texture size");

        _bloomPreserveAspectRatioProperty.boolValue =
            EditorGUILayout.ToggleLeft("Preserve aspect ratio", _bloomPreserveAspectRatioProperty.boolValue);

        var rect = EditorGUILayout.GetControlRect();
        var oneFourthOfWidth = rect.width * 0.25f;
        var xLabelRect = new Rect(rect.x, rect.y, oneFourthOfWidth, rect.height);
        var widthRect = new Rect(rect.x + oneFourthOfWidth, rect.y, oneFourthOfWidth, rect.height);
        var yLabelRect = new Rect(rect.x + oneFourthOfWidth * 2.0f, rect.y, oneFourthOfWidth, rect.height);
        var heightRect = new Rect(rect.x + oneFourthOfWidth * 3.0f, rect.y, oneFourthOfWidth, rect.height);

        if (!_bloomPreserveAspectRatioProperty.boolValue)
        {
            EditorGUI.LabelField(xLabelRect, "X");
            _selectedBloomWidthIndex = _selectedBloomWidthIndex != -1 ? _selectedBloomWidthIndex : 2;
            _selectedBloomWidthIndex = EditorGUI.Popup(widthRect, _selectedBloomWidthIndex, _bloomSizeVariants);
            _bloomWidthProperty.intValue = _bloomSizeVariantInts[_selectedBloomWidthIndex];
        }

        EditorGUI.LabelField(yLabelRect, "Y");
        _selectedBloomHeightIndex = _selectedBloomHeightIndex != -1 ? _selectedBloomHeightIndex : 2;
        _selectedBloomHeightIndex = EditorGUI.Popup(heightRect, _selectedBloomHeightIndex, _bloomSizeVariants);
        _bloomHeightProperty.intValue = _bloomSizeVariantInts[_selectedBloomHeightIndex];
    }

    private static void Header(string title, SerializedProperty isExpanded, SerializedProperty enabledField)
    {
        var enabled = enabledField.boolValue;
        var rect = GUILayoutUtility.GetRect(16.0f, 22.0f, FxStyles.Header);
        GUI.Box(rect, title, FxStyles.Header);

        var toggleRect = new Rect(rect.x + 4.0f, rect.y + 4.0f, 13.0f, 13.0f);
        var e = Event.current;

        switch (e.type)
        {
            case EventType.Repaint:
                FxStyles.HeaderCheckbox.Draw(toggleRect, false, false, enabled, false);
                break;
            case EventType.MouseDown:
            {
                const float kOffset = 2.0f;
                toggleRect.x -= kOffset;
                toggleRect.y -= kOffset;
                toggleRect.width += kOffset * 2.0f;
                toggleRect.height += kOffset * 2.0f;

                if (toggleRect.Contains(e.mousePosition))
                {
                    enabledField.boolValue = !enabledField.boolValue;
                    e.Use();
                }
                else if (rect.Contains(e.mousePosition) && isExpanded != null)
                {
                    isExpanded.boolValue = !isExpanded.boolValue;
                    e.Use();
                }

                break;
            }
            case EventType.MouseUp:
                break;
            case EventType.MouseMove:
                break;
            case EventType.MouseDrag:
                break;
            case EventType.KeyDown:
                break;
            case EventType.KeyUp:
                break;
            case EventType.ScrollWheel:
                break;
            case EventType.Layout:
                break;
            case EventType.DragUpdated:
                break;
            case EventType.DragPerform:
                break;
            case EventType.DragExited:
                break;
            case EventType.Ignore:
                break;
            case EventType.Used:
                break;
            case EventType.ValidateCommand:
                break;
            case EventType.ExecuteCommand:
                break;
            case EventType.ContextClick:
                break;
            case EventType.MouseEnterWindow:
                break;
            case EventType.MouseLeaveWindow:
                break;
            default:
                throw new ArgumentOutOfRangeException();
        }
    }

    private static string GetMemberName<T, TValue>(Expression<Func<T, TValue>> memberAccess)
    {
        return ((MemberExpression) memberAccess.Body).Member.Name;
    }
}