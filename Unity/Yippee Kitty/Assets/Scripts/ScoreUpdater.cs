using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class ScoreUpdater : MonoBehaviour
{
    public static ScoreUpdater instance;
    // Reference to the UI Text component
    private TextMeshProUGUI scoreText;

    // The score value
    public int score = 0;

    // Start is called before the first frame update
    void Start()
    {
        scoreText = GetComponentInChildren<TextMeshProUGUI>();
        if (scoreText == null)
        {
            Debug.LogError("TextMeshPro component not found!");
        }
        else
        {
            // Initialize the UI Text to display the starting score
            UpdateScoreText();
        }
    }

    private void Awake()
    {
        if (instance == null)
        {
            instance = this;
        }
        else
        {
            Debug.LogWarning("Another instance of ScoreUpdater already exists.");
            Destroy(gameObject); // Destroy this duplicate instance
        }
    }

    private void Update()
    {
        UpdateScoreText();
    }

    // Function to update the UI Text with the current score value
    void UpdateScoreText()
    {
        scoreText.text = score.ToString();
    }
}
