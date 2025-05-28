#!/bin/bash

echo "🔧 Security Scanning Lab Setup"
echo "================================"

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p reports
mkdir -p sample-app
mkdir -p dvwa-source

# Clean and prepare the code directory for scanning sources
echo "🧹 Ensuring a clean './code' directory for scanning sources..."
rm -rf ./code # Remove any existing/problematic ./code directory
mkdir -p ./code # Recreate a clean ./code directory

# Create sample app files
echo "📝 Creating sample vulnerable PHP application..."
cat > sample-app/.htaccess << 'EOF'
# Vulnerability: Weak Apache configuration
Options +Indexes +FollowSymLinks
AllowOverride All
Order allow,deny
Allow from all

# Directory listing enabled (information disclosure)
IndexOptions +FancyIndexing +HTMLTable +ScanHTMLTitles
EOF

# Add a sample index.php for the sample-app to have some scannable PHP code
cat > sample-app/index.php << 'EOF'
<?php
// Sample vulnerable PHP file
$name = isset($_GET['name']) ? $_GET['name'] : 'World';
echo "Hello, " . $name . "!"; // Potential XSS if name is not sanitized

$file = isset($_GET['file']) ? $_GET['file'] : 'default.txt';
include($file); // Potential LFI/RFI if file is not validated

$id = isset($_GET['id']) ? $_GET['id'] : '1';
$query = "SELECT * FROM users WHERE id = " . $id; // Potential SQL Injection
?>
EOF

cat > sample-app/config.php << 'EOF'
<?php
// Sample config file
define('DB_SERVER', 'localhost');
define('DB_USERNAME', 'root');
define('DB_PASSWORD', 'password');
define('DB_DATABASE', 'testdb');

// Example of hardcoded secret
$apiKey = "supersecretapikey123";
?>
EOF

echo "➕ Copying sample-app to ./code/sample-app for scanning..."
if [ -d "sample-app" ]; then
  mkdir -p ./code/sample-app
  cp -R sample-app/* ./code/sample-app/
else
  echo "⚠️ Warning: ./sample-app directory not found. Skipping copy to ./code/sample-app."
fi

echo "🚀 Starting the security lab environment..."
docker-compose up -d

echo "⏳ Waiting for services to start (code-collector needs time to clone)..."
# Increased sleep to allow code-collector to finish cloning, especially on first run
sleep 60 

echo "🎯 Lab Environment Ready!"
echo "=========================="
echo ""
echo "📊 Access Points:"
echo "• SonarQube: http://localhost:9000"
echo "• DVWA: http://localhost:8080 (Default credentials: admin/password)"
echo "• Sample Vulnerable App: http://localhost:3000"
echo ""
echo "🔍 Running Security Scans:"
echo "=========================="
echo ""


echo "🔸 Running Semgrep scan on DVWA..."
docker exec semgrep-scanner semgrep --config=auto /src/DVWA --json --output=/reports/semgrep-dvwa-auto.json
docker exec semgrep-scanner semgrep --config=p/security-audit /src/DVWA --json --output=/reports/semgrep-dvwa-security.json
docker exec semgrep-scanner semgrep --config=p/owasp-top-ten /src/DVWA --json --output=/reports/semgrep-dvwa-owasp.json

echo "🔸 Running Semgrep scan on sample-app..."
docker exec semgrep-scanner semgrep --config=auto /src/sample-app --json --output=/reports/semgrep-sample-app-auto.json
docker exec semgrep-scanner semgrep --config=p/security-audit /src/sample-app --json --output=/reports/semgrep-sample-app-security.json
docker exec semgrep-scanner semgrep --config=p/owasp-top-ten /src/sample-app --json --output=/reports/semgrep-sample-app-owasp.json

echo "✅ Semgrep scans completed! Results saved in ./reports/"

# Wait for SonarQube to be fully ready
echo "⏳ Waiting for SonarQube to be fully ready before SonarScans..."
sleep 60 # SonarQube can take a while to initialize plugins etc.

echo "🔸 Running SonarQube scan for DVWA..."
docker exec sonar-scanner sonar-scanner \
  -Dsonar.projectKey=dvwa-scan \
  -Dsonar.sources=/usr/src/DVWA \
  -Dsonar.host.url=http://sonarqube:9000 \
  -Dsonar.login=admin \
  -Dsonar.password=admin

echo "🔸 Running SonarQube scan for sample-php-app..."
docker exec sonar-scanner sonar-scanner \
  -Dsonar.projectKey=sample-php-scan \
  -Dsonar.sources=/usr/src/sample-app \
  -Dsonar.host.url=http://sonarqube:9000 \
  -Dsonar.login=admin \
  -Dsonar.password=admin

echo "✅ SonarQube scans completed! Check results at http://localhost:9000"

