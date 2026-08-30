using UnityEngine;
using System.Collections.Generic;
using System.Collections;
using Unity.VisualScripting;
using UnityEngine.Rendering;
using System;

public class DropperController : MonoBehaviour
{
    public static DropperController instance;
    public GameObject[] catsToSpawn;
    public List<float> catYOffsets;
    public Transform spawnPoint;
    public float moveSpeed;
    private float leftBound;
    private float rightBound;
    public float startingLeftBound;
    public float startingRightBound;
    public float spawnCooldown = 2f;
    private int currentCat = -1;
    public int nextCat;

    private Rigidbody2D catRigidbody;
    private PolygonCollider2D catCollider;
    private float horizontalInput;
    public bool canSpawnCat = true;

    private List<float> leftWidths = new List<float>();
    private List<float> rightWidths = new List<float>();

    public Animator animator1;
    public Animator animator2;

    public bool canControl = true;

    private void Start()
    {
        FindWidths();
        SpawnRandomCat();
    }

    private void Awake()
    {
        if (instance == null)
        {
            instance = this;
        }
        else
        {
            Debug.LogWarning("Another instance of DropperController already exists.");
            Destroy(gameObject); // Destroy this duplicate instance
        }
    }

    private void Update()
    {
        if (canControl)
        {
            horizontalInput = Input.GetAxisRaw("Horizontal");
            if (Input.GetKeyDown(KeyCode.Space) && canSpawnCat)
            {
                DetachCat();
            }
        }
    }

    private void FixedUpdate()
    {
        transform.Translate(Vector2.right * horizontalInput * moveSpeed * Time.fixedDeltaTime);

        Vector3 clampedPosition = transform.position;
        clampedPosition.x = Mathf.Clamp(clampedPosition.x, leftBound, rightBound);
        transform.position = clampedPosition;
    }

    private void SpawnRandomCat()
    {
        int maxIndex = Mathf.Min(5, catsToSpawn.Length);
        if (maxIndex > 0 && spawnPoint != null && catYOffsets.Count == catsToSpawn.Length)
        {
            // If there's no current cat, or if it's the first time spawning a cat
            if (currentCat == -1)
            {
                currentCat = UnityEngine.Random.Range(0, maxIndex); // Choose index from 0 to maxIndex
            }
            else // If there's already a current cat, switch it with the next in line cat
            {
                currentCat = nextCat;
            }

            GameObject spawnedObject = Instantiate(catsToSpawn[currentCat], spawnPoint.position + new Vector3(0, catYOffsets[currentCat], 0), Quaternion.identity);
            spawnedObject.transform.parent = transform;
            catRigidbody = spawnedObject.GetComponent<Rigidbody2D>();
            catCollider = spawnedObject.GetComponent<PolygonCollider2D>();

            // Set the next in line cat
            nextCat = UnityEngine.Random.Range(0, maxIndex);

            // Update left and right bounds based on the corresponding left and right widths of the spawned cat
            leftBound = startingLeftBound + leftWidths[currentCat] + 0.55f;
            rightBound = startingRightBound - rightWidths[currentCat] -0.55f;

            Debug.Log("Spawned Cat Index: " + currentCat);
            Debug.Log("Next Cat Index: " + nextCat);
            //Debug.Log("Left Width of Spawned Cat: " + leftWidths[currentCat]);
            //Debug.Log("Right Width of Spawned Cat: " + rightWidths[currentCat]);
            //Debug.Log("Adjusted Left Bound: " + leftBound);
            //Debug.Log("Adjusted Right Bound: " + rightBound);
        }
        else
        {
            Debug.LogWarning("No prefabs in the list, spawn point not assigned, or cat Y offsets not set properly.");
        }
    }


    private void DetachCat()
    {
        if (catRigidbody != null)
        {
            // Setting the animator bool parameter for specific animators
            if (animator1 != null)
                animator1.SetBool("isDropping", true);
            if (animator2 != null)
                animator2.SetBool("isDropping", true);

            catRigidbody.transform.parent = null;
            catRigidbody.simulated = true;
            catCollider.enabled = true;
            StartCoroutine(SpawnCooldownTimer());
        }
        else
        {
            Debug.LogWarning("Prefab Rigidbody2D not found.");
        }
    }

    
    private IEnumerator SpawnCooldownTimer()
    {
        canSpawnCat = false;

        while (!canSpawnCat)
        {
            yield return null; // Wait for the next frame
        }
        if (animator1 != null)
            animator1.SetBool("isDropping", false);
        if (animator2 != null)
            animator2.SetBool("isDropping", false);
        SpawnRandomCat();
    }
    

    private void FindWidths()
    {
        // Iterate through the list of prefabs
        foreach (GameObject prefab in catsToSpawn)
        {
            // Get the points of the PolygonCollider2D
            PolygonCollider2D collider = prefab.GetComponent<PolygonCollider2D>();
            if (collider == null)
            {
                Debug.LogError("Prefab does not have a PolygonCollider2D!");
                return;
            }

            Vector2[] points = collider.points;

            // Calculate the farthest left and right points from the pivot
            float farthestLeft = float.MaxValue;
            float farthestRight = float.MinValue;

            // Calculate the pivot point (center of the collider)
            Vector2 center = collider.bounds.center;

            foreach (Vector2 point in points)
            {
                // Transform the local point position to world space
                Vector2 worldPoint = (Vector2)prefab.transform.TransformPoint(point);

                // Check if the point is to the left or right of the pivot
                if (worldPoint.x < center.x && worldPoint.x < farthestLeft)
                {
                    farthestLeft = worldPoint.x;
                }
                else if (worldPoint.x > center.x && worldPoint.x > farthestRight)
                {
                    farthestRight = worldPoint.x;
                }
            }

            // Calculate the widths of the left and right halves
            float leftWidth = Mathf.Abs(center.x - farthestLeft);
            float rightWidth = Mathf.Abs(farthestRight - center.x);

            leftWidths.Add(leftWidth);
            rightWidths.Add(rightWidth);
        }
    }
}