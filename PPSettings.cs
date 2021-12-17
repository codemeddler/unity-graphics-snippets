using System;
using UnityEngine;

[CreateAssetMenu(menuName = "Post Processing Settings")]
[Serializable]
public class PPSettings : ScriptableObject
{
    [Header("Bloom")] public bool bloomExpanded;
    public bool bloomEnabled = true;
    public float bloomThreshold = 0.6f;
    public float bloomIntensity = 2.5f;
    public Color bloomTint = Color.white;

    public bool preserveAspectRatio;
    public int bloomTextureWidth = 128;
    public int bloomTextureHeight = 128;

    public LuminanceVectorType bloomLuminanceCalculationType = LuminanceVectorType.Uniform;
    public Vector3 bloomLuminanceVector = new Vector3(1.0f / 3.0f, 1.0f / 3.0f, 1.0f / 3.0f);
}

public enum LuminanceVectorType
{
    Uniform,
    sRGB,
    Custom
}