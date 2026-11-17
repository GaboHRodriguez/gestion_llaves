<?php
/**
 * Endpoint REST para Gestión de Llaves y Vectores (XAMPP PHP / PDO MySQL)
 * Ubicación sugerida: C:/xampp/htdocs/gestion_llaves/api/llaves.php
 */
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, X-User-Id, X-User-Role");
header("Access-Control-Allow-Methods: GET, POST, PUT, OPTIONS");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$dsn = "mysql:host=127.0.0.1;dbname=gestion_llaves_db;charset=utf8mb4";
$pdo = new PDO($dsn, "root", "", [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
]);

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    if (!empty($_GET['id_edificio'])) {
        $stmt = $pdo->prepare("SELECT * FROM llaves WHERE id_edificio = ? ORDER BY codigo_interno ASC");
        $stmt->execute([strtoupper(trim($_GET['id_edificio']))]);
    } else {
        $stmt = $pdo->query("SELECT * FROM llaves ORDER BY codigo_interno ASC");
    }
    echo json_encode(["status" => "ok", "data" => $stmt->fetchAll()]);
    exit;
}

$input = json_decode(file_get_contents("php://input"), true) ?? [];

if ($method === 'POST') {
    if (($input['action'] ?? '') === 'delete') {
        $stmt = $pdo->prepare("DELETE FROM llaves WHERE codigo_interno = ?");
        $stmt->execute([$input['codigo_interno']]);
        echo json_encode(["status" => "deleted"]);
        exit;
    }

    $sql = "INSERT INTO llaves (codigo_interno, id_edificio, piso_depto, zona_comun, tipo_llave, vector_data, estado)
            VALUES (:codigo_interno, :id_edificio, :piso_depto, :zona_comun, :tipo_llave, :vector_data, :estado)
            ON DUPLICATE KEY UPDATE
              piso_depto = VALUES(piso_depto),
              zona_comun = VALUES(zona_comun),
              tipo_llave = VALUES(tipo_llave),
              vector_data = VALUES(vector_data),
              estado = VALUES(estado)";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        ':codigo_interno' => $input['codigo_interno'],
        ':id_edificio'    => $input['id_edificio'],
        ':piso_depto'     => $input['piso_depto'] ?? '',
        ':zona_comun'     => $input['zona_comun'] ?? '',
        ':tipo_llave'     => $input['tipo_llave'] ?? 'sierra',
        ':vector_data'    => is_string($input['vector_data']) ? $input['vector_data'] : json_encode($input['vector_data']),
        ':estado'         => $input['estado'] ?? 'disponible',
    ]);
    echo json_encode(["status" => "saved", "codigo_interno" => $input['codigo_interno']]);
    exit;
}

if ($method === 'PUT') {
    $stmt = $pdo->prepare("UPDATE llaves SET estado = ? WHERE codigo_interno = ?");
    $stmt->execute([$input['estado'], $input['codigo_interno']]);
    echo json_encode(["status" => "updated"]);
    exit;
}
