using UnityEngine;

public class LineFollow : MonoBehaviour
{
    public LineRenderer lineRenderer;

    void Update()
    {
        if (lineRenderer == null)
        {
            Debug.LogWarning("Line Renderer not assigned!");
            return;
        }

        // Get the current object's x-position
        float objectX = transform.position.x;

        // Get the number of points in the line renderer
        int pointCount = lineRenderer.positionCount;

        // Create a new array to store the positions
        Vector3[] positions = new Vector3[pointCount];

        // Loop through each point and update its x-value to match the object's x-position
        for (int i = 0; i < pointCount; i++)
        {
            Vector3 point = lineRenderer.GetPosition(i);
            point.x = objectX;
            positions[i] = point;
        }

        // Assign the updated positions to the line renderer
        lineRenderer.SetPositions(positions);
    }
}
