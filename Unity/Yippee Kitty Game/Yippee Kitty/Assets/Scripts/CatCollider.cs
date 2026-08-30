using System.Collections;
using System.Collections.Generic;
using UnityEditor.Build;
using UnityEngine;

public class CatCollider : MonoBehaviour
{
    private int _layerIndex; // Layer index of the cat

    private CatData _data; // Data associated with the cat

    private void Awake()
    {
        _data = GetComponent<CatData>(); // Getting CatData component attached to the cat
        _layerIndex = gameObject.layer; // Storing the layer index of the cat
    }

    private void OnCollisionEnter2D(Collision2D collision)
    {
        if (collision.gameObject.layer == _layerIndex)
        {
            CatData data = collision.gameObject.GetComponent<CatData>(); // Getting CatData component of the collided object

            // Debugging to check if CatData component exists
            if (data != null)
            {
                Debug.Log("CatData component exists.");

                if (data.CatIndex == _data.CatIndex) // Checking if both cats have the same index
                {
                    Debug.Log("CatIndex matches.");

                    int thisID = gameObject.GetInstanceID(); // Getting instance ID of the current cat
                    int otherID = collision.gameObject.GetInstanceID(); // Getting instance ID of the collided cat

                    if (thisID > otherID) // Ensuring that only one cat handles the collision
                    {
                        Debug.Log("Handling collision.");

                        if (_data.CatIndex == DropperController.instance.catsToSpawn.Length - 1)
                        {
                            Debug.Log("Last cat in array.");
                            ScoreUpdater.instance.score += _data.CatPoints;
                            // If the current cat is the last in the array, destroy both cats
                            Destroy(collision.gameObject);
                            Destroy(gameObject);
                            
                        }
                        else
                        {
                            Debug.Log("Not the last cat in array.");
                            // If not the last cat, spawn a combined cat
                            Vector3 middlePosition = (transform.position + collision.transform.position) / 2f; // Finding middle position between two cats
                            GameObject go = Instantiate(SpawnCombinedCat(_data.CatIndex), GameManager.instance.transform);
                            Rigidbody2D goRigidbody = go.GetComponent<Rigidbody2D>();
                            PolygonCollider2D goCollider = go.GetComponent <PolygonCollider2D>();
                            go.transform.position = middlePosition; // Positioning the combined cat
                            goRigidbody.simulated = true;
                            goCollider.enabled= true;

                            // Informing the combined cat that it was created through a combination
                            ColliderInformer informer = go.GetComponent<ColliderInformer>();
                            if (informer != null)
                            {
                                informer.WasCombinedIn = true;
                            }

                            if (ScoreUpdater.instance != null && _data != null)
                            {
                                ScoreUpdater.instance.score += _data.CatPoints;
                            }
                            else
                            {
                                Debug.Log("ScoreUpdater.instance: " + ScoreUpdater.instance);
                                Debug.Log("_data: " + _data);
                                Debug.LogWarning("ScoreUpdater instance or _data is null.");
                            }


                            // Destroying the collided cat and the current cat
                            Destroy(collision.gameObject);
                            Destroy(gameObject);
                        }
                    }
                }
                else
                {
                    Debug.Log("CatIndex does not match.");
                }
            }
            else
            {
                Debug.LogError("CatData component is null.");
            }
        }
    }

    // Method to spawn a combined cat based on its index
    private GameObject SpawnCombinedCat(int index)
    {
        GameObject go = DropperController.instance.catsToSpawn[index + 1]; // Retrieving the combined cat prefab
        return go;
    }
}
