<?php
$domain = $argv[1];
$record = $argv[2];
$type = $argv[3];
$proxy = filter_var($argv[4], FILTER_VALIDATE_BOOLEAN);
$apiToken = $argv[5];
$zoneId = $argv[6];

$endpoint = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records";

if ($record === "@" || empty($record)) {
    $fullname = $domain;
} else {
    $fullname = "$record.$domain";
}

echo "🔍 Buscando registro: $fullname (tipo: $type)\n";

$ch = curl_init("$endpoint?name=$fullname&type=$type");
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    "Authorization: Bearer $apiToken",
    "Content-Type: application/json"
]);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($httpCode !== 200) {
    echo "❌ Error HTTP $httpCode al consultar Cloudflare\n";
    exit(1);
}

$result = json_decode($response, true);

if (isset($result['result'][0])) {
    $recordId = $result['result'][0]['id'];
    $content = $result['result'][0]['content'];
    $currentProxied = $result['result'][0]['proxied'];

    if ($currentProxied === $proxy) {
        echo "ℹ️ Registro $fullname ya está en el estado deseado (proxied=$proxy)\n";
        exit(0);
    }

    $payload = json_encode([
        "type" => $type,
        "name" => $fullname,
        "content" => $content,
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
    $updateCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($updateCode === 200) {
        echo "✅ Registro $fullname actualizado: proxied=" . ($proxy ? "✓" : "✗") . " (IP: $content)\n";
    } else {
        echo "❌ Error HTTP $updateCode al actualizar $fullname\n";
    }
} else {
    echo "❌ Registro $fullname no encontrado en Cloudflare\n";
    echo "💡 Verifica que el registro existe y el tipo es correcto\n";
}
