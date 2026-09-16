<?php
// Fake router for dry-run smoke (php -S localhost:PORT router.php)
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
header('Content-Type: application/json; charset=utf-8');
if ($path === '/api/website/info') {
    echo json_encode(['code' => 0, 'data' => ['name' => 'fake']]);
    return true;
}
if ($path === '/api/testlogin/login') {
    echo json_encode(['code' => 0, 'data' => ['token' => 'fake-token']]);
    return true;
}
if ($path === '/api/user/info') {
    echo json_encode(['code' => 0, 'data' => ['id' => 1]]);
    return true;
}
http_response_code(404);
echo json_encode(['code' => -1, 'message' => 'not found']);
return true;
