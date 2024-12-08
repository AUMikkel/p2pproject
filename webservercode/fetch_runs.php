<?php
// fetch_runs.php
header("Content-Type: application/json");

// Fetch data from the API
$apiUrl = "https://app.dokkedalleth.dk/routes.php";

$response = file_get_contents($apiUrl);
if ($response === FALSE) {
    echo json_encode(["error" => "Failed to fetch data from API"]);
    exit;
}

$data = json_decode($response, true);
if ($data['success']) {
    echo json_encode($data['routes']); // Return routes only
} else {
    echo json_encode(["error" => $data['error'] ?? "Unknown error"]);
}
?>
