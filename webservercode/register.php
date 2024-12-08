<?php
$host = "*****";
$db = "dokkedalleth_dk_db_p2p";
$user = "dokkedalleth_dk";
$pass = "******";

$conn = new mysqli($host, $user, $pass, $db);

if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// Get data from POST request
$data = json_decode(file_get_contents("php://input"), true);
$username = $data['username']; 
$email = $data['email'];
$password = $data['password'];

// Validate input
if (empty($username) || empty($email) || empty($password)) {
    echo json_encode(["success" => false, "error" => "All fields are required."]);
    exit();
}

// Check if the email already exists
$sql = "SELECT id FROM users WHERE email = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $email);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    echo json_encode(["success" => false, "error" => "Email is already registered."]);
    exit();
}

// Hash the password securely
$passwordHash = password_hash($password, PASSWORD_BCRYPT);

// Insert the new user into the database
$sql = "INSERT INTO users (username, email, password_hash) VALUES (?, ?, ?)";
$stmt = $conn->prepare($sql);
$stmt->bind_param("sss", $username, $email, $passwordHash);

if ($stmt->execute()) {
    echo json_encode(["success" => true, "user_id" => $stmt->insert_id]);
} else {
    echo json_encode(["success" => false, "error" => "Registration failed: " . $stmt->error]);
}

$conn->close();
?>
