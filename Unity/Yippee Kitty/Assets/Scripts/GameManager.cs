using UnityEngine;
using TMPro;
using System.Collections.Generic;

public class GameManager : MonoBehaviour
{
    public static GameManager instance;

    public Canvas gameOverScreen;
    public TextMeshProUGUI[] highScoreTexts; // Array to hold TextMeshPro objects for high scores

    // Key for PlayerPrefs
    private const string HighScoresKey = "HighScores";

    // List to store high scores
    private List<int> highScores = new List<int>();

    public void Start()
    {
        gameOverScreen.enabled = false;

        // Initialize high score texts
        for (int i = 0; i < highScoreTexts.Length; i++)
        {
            highScoreTexts[i].text = "";
        }

        // Display high scores
        DisplayHighScores();
    }

    public void Awake()
    {
        if (instance == null)
        {
            instance = this;
        }
    }

    public void gameOver()
    {
        DropperController.instance.canControl = false;
        gameOverScreen.enabled = true;

        // Add the current score to the high scores list
        int currentScore = ScoreUpdater.instance.score;
        AddHighScore(currentScore);
        DisplayHighScores(); // Update displayed high scores
    }

    // Add a high score to the list
    private void AddHighScore(int score)
    {
        LoadHighScores(); // Load existing high scores

        if (!highScores.Contains(score))
        {
            highScores.Add(score);
            highScores.Sort((a, b) => b.CompareTo(a)); // Sort in descending order

            // Truncate list to keep only top 10 high scores
            if (highScores.Count > 10)
            {
                highScores.RemoveRange(10, highScores.Count - 10);
            }

            SaveHighScores(); // Save updated high scores only when necessary
        }
    }


    // Save high scores to PlayerPrefs
    private void SaveHighScores()
    {
        string serializedList = string.Join(",", highScores.ConvertAll(i => i.ToString()).ToArray());
        PlayerPrefs.SetString(HighScoresKey, serializedList);
        PlayerPrefs.Save();
    }

    // Load high scores from PlayerPrefs
    private void LoadHighScores()
    {
        if (PlayerPrefs.HasKey(HighScoresKey))
        {
            string serializedList = PlayerPrefs.GetString(HighScoresKey);
            string[] scoreStrings = serializedList.Split(',');
            highScores = new List<int>();

            foreach (string scoreString in scoreStrings)
            {
                int score;
                if (int.TryParse(scoreString, out score))
                {
                    highScores.Add(score);
                }
            }
        }
        else
        {
            // If no high scores are found, initialize with an empty list
            highScores = new List<int>();
        }
    }

    // Display high scores using TextMeshPro objects
    private void DisplayHighScores()
    {
        LoadHighScores(); // Load high scores before displaying

        // Display first 5 high scores using TextMeshPro objects
        int numScoresToDisplay = Mathf.Min(highScores.Count, 5);
        for (int i = 0; i < numScoresToDisplay; i++)
        {
            highScoreTexts[i].text = "#" + (i + 1) + " - " + highScores[i];
        }

        // Display "0" as a placeholder for empty positions
        for (int i = numScoresToDisplay; i < highScoreTexts.Length; i++)
        {
            highScoreTexts[i].text = "#" + (i + 1) + " - 0";
        }
    }

}
