using UnityEngine;

// Custom component editor view definition
[AddComponentMenu("Effects/Post Process")]
[RequireComponent(typeof(Camera))]
[ExecuteInEditMode, DisallowMultipleComponent]
public class PPPostProcess : MonoBehaviour
{
    private static class Uniforms
    {
        public static readonly int LuminanceConst = Shader.PropertyToID("_LuminanceConst");
        public static readonly int BloomIntensity = Shader.PropertyToID("_BloomIntensity");
        public static readonly int BloomTint = Shader.PropertyToID("_BloomTint");
        public static readonly int MainTex = Shader.PropertyToID("_MainTex");
        public static readonly int BloomTex = Shader.PropertyToID("_BloomTex");
        public static readonly int PreComposeTex = Shader.PropertyToID("_PreComposeTex");
        public static readonly int TexelSize = Shader.PropertyToID("_TexelSize");
    }

    // Currently linked settings in the inspector
    public PPSettings settings;

    // Various Material cached objects
    // Created dynamically from found and loaded shaders
    private Material _downSampleMaterial;
    private Material _horizontalBlurMaterial;
    private Material _verticalBlurMaterial;
    private Material _preComposeMaterial;
    private Material _composeMaterial;

    // Various RenderTextures used in post processing render passes
    private RenderTexture _downSampledBrightPassTexture;
    private RenderTexture _brightPassBlurTexture;
    private RenderTexture _horizontalBlurTexture;
    private RenderTexture _verticalBlurTexture;
    private RenderTexture _preComposeTexture;

    // Currently cached camera on which Post Processing stack is applied
    private Camera _mainCamera;

    // Quad mesh used in full screen custom blit
    private Mesh _fullscreenQuadMesh;

    // Cached camera width and height. Used in editor code for checking updated size for recreating resources
    private int _currentCameraPixelWidth;
    private int _currentCameraPixelHeight;

    private bool _isAlreadyPreservingAspectRatio;

    private void OnEnable()
    {
        // If we are adding a component from scratch, we should supply fake settings with default values 
        // (until normal ones are linked)
        CreateDefaultSettingsIfNoneLinked();
        CreateResources();
    }

    private void OnDisable()
    {
        ReleaseResources();
    }

    private void OnRenderImage(RenderTexture source, RenderTexture target)
    {
        if (!settings.bloomEnabled)
        {
            Graphics.Blit(source, target);
            return;
        }

        // Editor only behaviour needed to recreate resources if viewport size changes (resizing editor window)
#if UNITY_EDITOR
        CreateDefaultSettingsIfNoneLinked();
        CheckScreenSizeAndRecreateTexturesIfNeeded(_mainCamera);
#endif
        
        // Applying post processing steps
        PreCompose(source);
        // Last step as separate pass
        Compose(source, target);
        PostCompose();
    }

    private void PreCompose(Texture source)
    {
        var oneOverOneMinusBloomThreshold = 1f / (1f - settings.bloomThreshold);
        var luminance = settings.bloomLuminanceVector;
        var luminanceConst = new Vector4(
            luminance.x * oneOverOneMinusBloomThreshold,
            luminance.y * oneOverOneMinusBloomThreshold,
            luminance.z * oneOverOneMinusBloomThreshold, -settings.bloomThreshold * oneOverOneMinusBloomThreshold);

        // Changing current Luminance Const value just to make sure that we have the latest settings in our Uniforms
        _downSampleMaterial.SetVector(Uniforms.LuminanceConst, luminanceConst);

        // Applying down sample + bright pass (stored in Alpha)
        Blit(source, _downSampledBrightPassTexture, _downSampleMaterial);

        // Applying horizontal and vertical Separable Gaussian Blur passes
        Blit(_downSampledBrightPassTexture, _brightPassBlurTexture, _horizontalBlurMaterial);
        Blit(_brightPassBlurTexture, _verticalBlurTexture, _verticalBlurMaterial);

        // Bloom is handled in two different passes (two blurring bloom passes and one pre-compose pass)
        // So we need to check for whether it's enabled in pre-compose step too (shader has variants without bloom)
        _preComposeMaterial.SetFloat(Uniforms.BloomIntensity, settings.bloomIntensity);
        _preComposeMaterial.SetColor(Uniforms.BloomTint, settings.bloomTint);

        // Finally applying pre-compose step. It slaps bloom and vignette together
        Blit(_downSampledBrightPassTexture, _preComposeTexture, _preComposeMaterial);
    }

    private void Compose(Texture source, RenderTexture target)
    {
        // Composing pass includes using full size main render texture + pre-compose texture
        // Pre-compose texture contains valuable info in its Alpha channel (whether to apply it on the final image or not)
        // Compose step also includes uniform colorizing which is calculated and enabled / disabled separately
        Blit(source, target, _composeMaterial);
    }

    private void PostCompose()
    {
        _downSampledBrightPassTexture.DiscardContents();
        _brightPassBlurTexture.DiscardContents();
        _horizontalBlurTexture.DiscardContents();
        _verticalBlurTexture.DiscardContents();
        _preComposeTexture.DiscardContents();
        RenderTexture.active = null;
    }

    private void CreateResources()
    {
        _mainCamera = GetComponent<Camera>();

        var downSampleShader = Shader.Find("Post Process/Down Sample Bright Pass");
        var horizontalBlurShader = Shader.Find("Post Process/Horizontal Blur");
        var verticalBlurShader = Shader.Find("Post Process/Vertical Blur");
        var composeShader = Shader.Find("Post Process/Compose");
        var preComposeShader = Shader.Find("Post Process/PreCompose");

        _downSampleMaterial = new Material(downSampleShader);
        _horizontalBlurMaterial = new Material(horizontalBlurShader);
        _verticalBlurMaterial = new Material(verticalBlurShader);
        _preComposeMaterial = new Material(preComposeShader);
        _composeMaterial = new Material(composeShader);

        _currentCameraPixelWidth = Mathf.RoundToInt(_mainCamera.pixelWidth);
        _currentCameraPixelHeight = Mathf.RoundToInt(_mainCamera.pixelHeight);

        // Point for future main render target size changing
        var width = _currentCameraPixelWidth;
        var height = _currentCameraPixelHeight;

        // Capping max base texture height in pixels
        // We usually don't need extra pixels for pre-compose and blur passes
        var maxHeight = Mathf.Min(height, 720);
        var ratio = (float) maxHeight / height;

        // Constant used to make the bloom look completely uniform on square or circle objects
        var blurHeight = settings.bloomTextureHeight;
        var blurWidth = settings.preserveAspectRatio
            ? Mathf.RoundToInt(blurHeight * GetCurrentAspect(_mainCamera))
            : settings.bloomTextureWidth;

        // Down sampling texture size (downscale + bright pass and pre-compose)
        var downSampleWidth = Mathf.RoundToInt((width * ratio) / 5.0f);
        var downSampleHeight = Mathf.RoundToInt((height * ratio) / 5.0f);

        _downSampledBrightPassTexture =
            CreateTransientRenderTexture("Bloom Down Sample Pass", downSampleWidth, downSampleHeight);
        _brightPassBlurTexture = CreateTransientRenderTexture("Pre Bloom", blurWidth, blurHeight);
        _horizontalBlurTexture = CreateTransientRenderTexture("Horizontal Blur", blurWidth, blurHeight);
        _verticalBlurTexture = CreateTransientRenderTexture("Vertical Blur", blurWidth, blurHeight);
        _preComposeTexture = CreateTransientRenderTexture("Pre Compose", downSampleWidth, downSampleHeight);

        _verticalBlurMaterial.SetTexture(Uniforms.MainTex, _downSampledBrightPassTexture);
        _verticalBlurMaterial.SetTexture(Uniforms.BloomTex, _horizontalBlurTexture);

        var xSpread = 1.0f / blurWidth;
        var ySpread = 1.0f / blurHeight;
        var blurTexelSize = new Vector4(xSpread, ySpread);
        _verticalBlurMaterial.SetVector(Uniforms.TexelSize, blurTexelSize);
        _horizontalBlurMaterial.SetVector(Uniforms.TexelSize, blurTexelSize);

        _preComposeMaterial.SetTexture(Uniforms.BloomTex, _verticalBlurTexture);

        var downSampleTexelSize = new Vector4(1.0f / _downSampledBrightPassTexture.width,
            1.0f / _downSampledBrightPassTexture.height);
        _downSampleMaterial.SetVector(Uniforms.TexelSize, downSampleTexelSize);

        _composeMaterial.SetTexture(Uniforms.PreComposeTex, _preComposeTexture);
        _composeMaterial.SetVector(Uniforms.LuminanceConst, new Vector4(0.2126f, 0.7152f, 0.0722f, 0.0f));

        _fullscreenQuadMesh = CreateScreenSpaceQuadMesh();
    }

    private static RenderTexture CreateTransientRenderTexture(string textureName, int width, int height)
    {
        var renderTexture = new RenderTexture(width, height, 0, RenderTextureFormat.ARGB32)
        {
            name = textureName, filterMode = FilterMode.Bilinear, wrapMode = TextureWrapMode.Clamp
        };
        return renderTexture;
    }

    private void ReleaseResources()
    {
        DestroyImmediateIfNotNull(_downSampleMaterial);
        DestroyImmediateIfNotNull(_horizontalBlurMaterial);
        DestroyImmediateIfNotNull(_verticalBlurMaterial);
        DestroyImmediateIfNotNull(_preComposeMaterial);
        DestroyImmediateIfNotNull(_composeMaterial);

        DestroyImmediateIfNotNull(_downSampledBrightPassTexture);
        DestroyImmediateIfNotNull(_brightPassBlurTexture);
        DestroyImmediateIfNotNull(_horizontalBlurTexture);
        DestroyImmediateIfNotNull(_verticalBlurTexture);
        DestroyImmediateIfNotNull(_preComposeTexture);

        DestroyImmediateIfNotNull(_fullscreenQuadMesh);
    }

    private static void DestroyImmediateIfNotNull(Object obj)
    {
        if (obj != null)
        {
            DestroyImmediate(obj);
        }
    }

    private void Blit(Texture source, RenderTexture destination, Material material, int materialPass = 0)
    {
        SetActiveRenderTextureAndClear(destination);
        DrawFullscreenQuad(source, material, materialPass);
    }

    private static void SetActiveRenderTextureAndClear(RenderTexture destination)
    {
        RenderTexture.active = destination;
        GL.Clear(true, true, new Color(1.0f, 0.75f, 0.5f, 0.8f));
    }

    private void DrawFullscreenQuad(Texture source, Material material, int materialPass = 0)
    {
        material.SetTexture(Uniforms.MainTex, source);
        material.SetPass(materialPass);
        Graphics.DrawMeshNow(_fullscreenQuadMesh, Matrix4x4.identity);
    }

    private void CheckScreenSizeAndRecreateTexturesIfNeeded(Camera mainCamera)
    {
        var cameraSizeHasChanged = mainCamera.pixelWidth != _currentCameraPixelWidth ||
                                   mainCamera.pixelHeight != _currentCameraPixelHeight;

        var bloomSizeHasChanged = _horizontalBlurTexture.height != settings.bloomTextureHeight;
        if (!settings.preserveAspectRatio)
        {
            bloomSizeHasChanged |= _horizontalBlurTexture.width != settings.bloomTextureWidth;
        }

        if (!bloomSizeHasChanged && settings.preserveAspectRatio)
        {
            if (_horizontalBlurTexture.width !=
                Mathf.RoundToInt(_horizontalBlurTexture.height * GetCurrentAspect(mainCamera)))
            {
                bloomSizeHasChanged = true;
            }
        }

        if (settings.preserveAspectRatio && !_isAlreadyPreservingAspectRatio
            || !settings.preserveAspectRatio && _isAlreadyPreservingAspectRatio)
        {
            _isAlreadyPreservingAspectRatio = settings.preserveAspectRatio;
            bloomSizeHasChanged = true;
        }

        if (!cameraSizeHasChanged && !bloomSizeHasChanged) return;
        ReleaseResources();
        CreateResources();
    }

    private static float GetCurrentAspect(Camera mainCamera)
    {
        const float squareAspectCorrection = 0.7f;
        return mainCamera.aspect * squareAspectCorrection;
    }

    private void CreateDefaultSettingsIfNoneLinked()
    {
        if (settings != null) return;
        settings = ScriptableObject.CreateInstance<PPSettings>();
        settings.name = "Default Settings";
    }

    private static Mesh CreateScreenSpaceQuadMesh()
    {
        var mesh = new Mesh();

        var vertices = new[]
        {
            new Vector3(-1.0f, -1.0f, 0.0f), // BL
            new Vector3(-1.0f, 1.0f, 0.0f), // TL
            new Vector3(1.0f, 1.0f, 0.0f), // TR
            new Vector3(1.0f, -1.0f, 0.0f) // BR
        };

        var uvs = new[]
        {
            new Vector2(0.0f, 0.0f),
            new Vector2(0.0f, 1.0f),
            new Vector2(1.0f, 1.0f),
            new Vector2(1.0f, 0.0f)
        };

        var colors = new[]
        {
            new Color(0.0f, 0.0f, 1.0f),
            new Color(0.0f, 1.0f, 1.0f),
            new Color(1.0f, 1.0f, 1.0f),
            new Color(1.0f, 0.0f, 1.0f),
        };

        var triangles = new[]
        {
            0,
            2,
            1,
            0,
            3,
            2
        };

        mesh.vertices = vertices;
        mesh.uv = uvs;
        mesh.triangles = triangles;
        mesh.colors = colors;
        mesh.UploadMeshData(true);

        return mesh;
    }
}