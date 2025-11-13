<?php
$feedUrl = $argv[1];

// Seguridad: solo se permite el dominio oficial
if (strpos($feedUrl, 'hayahora.futbol') === false) {
    echo "false";
    exit;
}

$data = @json_decode(file_get_contents($feedUrl), true);
$footballActive = false;

if (isset($data['data']) && is_array($data['data'])) {
    foreach ($data['data'] as $entry) {
        if (isset($entry['description']) && $entry['description'] === 'No-IP') {
            if (isset($entry['stateChanges']) && is_array($entry['stateChanges'])) {
                $lastChange = end($entry['stateChanges']);
                if (isset($lastChange['state']) && $lastChange['state'] === true) {
                    $footballActive = true;
                    break;
                }
            }
        }
    }
}

echo $footballActive ? "true" : "false";
