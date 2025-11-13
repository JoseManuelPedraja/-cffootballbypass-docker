<?php
$domain = $argv[1];
$record = $argv[2];
$type = $argv[3];
$proxy = filter_var($argv[4], FILTER_VALIDATE_BOOLEAN);
$apiToken = $argv[5];
$zoneId = $argv[6];

$endpoint = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records";

// Obtener registro DNS
$ch = curl_init("$endpoint?name=$record.$domain&type=$type");
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    "Authorization: Bearer $apiToken",
    "Content-Type: application/json"
]);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
$response = curl_exec($ch);
curl_close($ch);

$result = json_decode($response, true);

if (isset($result['result'][0])) {
    $recordId = $result['result'][0]['id'];
    $payload = json_encode([
        "type" => $type,
        "name" => $record,
        "content" => $result['result'][0]['content'],
        "proxied" => $proxy
    ]);

    $ch = curl_init("$endpoint/$recordId");
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        "Authorization: Bearer $apiToken",
        "Content-Type: application/json"
    ]);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "PUT");
    curl_setopt($ch, CURLOPT_POSTFIELDS, $payload);
    $resp = curl_exec($ch);
    curl_close($ch);

    echo "Registro $record.$domain actualizado (proxied=$proxy)\n";
} else {
    echo "Registro $record.$domain no encontrado\n";
}
