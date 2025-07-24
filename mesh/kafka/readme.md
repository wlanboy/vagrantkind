# Schulung: Apache Kafka Cluster Betrieb unter Red Hat

Dieses Dokument fasst die Inhalte der Schulung zum Betrieb eines Apache Kafka Clusters auf Red Hat Systemen zusammen. Es dient als Leitfaden für das Betriebsteam, um Kafka-Komponenten zu verstehen, den Cluster zu überwachen, Wartungsaufgaben durchzuführen und Fehler effektiv zu beheben.

---

## 1. Einführung in Apache Kafka und Red Hat

### Was ist Kafka?
Apache Kafka ist eine verteilte Streaming-Plattform, die für den Bau von echtzeitfähigen Daten-Pipelines und Streaming-Anwendungen entwickelt wurde. Sie zeichnet sich durch hohe Skalierbarkeit, Fehlertoleranz und hohen Durchsatz aus.

* **Anwendungsfälle:** Echtzeit-Monitoring, Log-Aggregation, Event Sourcing, Stream Processing.
* **Kernkonzepte:**
    * **Topics:** Kategorien oder Namen von Datenströmen, an die Produzenten Nachrichten senden und von denen Konsumenten lesen.
    * **Partitionen:** Topics sind in Partitionen unterteilt, die die Daten parallel speichern und lesen lassen. Innerhalb einer Partition sind Nachrichten sequenziell geordnet.
    * **Broker:** Die Kafka-Server, die die Partitionen hosten und Nachrichten speichern. Ein Kafka-Cluster besteht aus mehreren Brokern.
    * **Zookeeper:** Ein dezentraler Koordinationsdienst, der Konfigurationsinformationen für den Kafka-Cluster speichert, Namensdienste bereitstellt und Leader-Wahlen durchführt.
    * **Produzenten:** Anwendungen, die Nachrichten an Kafka-Topics senden.
    * **Konsumenten:** Anwendungen, die Nachrichten von Kafka-Topics lesen.
    * **Consumer Groups:** Eine Gruppe von Konsumenten, die sich die Last des Lesens von einem Topic teilen. Jede Partition wird innerhalb einer Gruppe nur von einem Konsumenten gelesen.
    * **Offset:** Eine eindeutige, sequentielle ID einer Nachricht innerhalb einer Partition. Konsumenten verfolgen ihren Fortschritt (Current Offset) durch Speichern des Offsets.
    * **Lag:** Die Differenz zwischen dem letzten verfügbaren Offset (`LOG-END-OFFSET`) und dem letzten von einem Konsumenten verarbeiteten Offset (`CURRENT-OFFSET`) in einer Partition. Hohe Lags bedeuten, dass der Konsument hinterherhinkt.

### Kafka im Red Hat Umfeld
Kafka wird typischerweise auf Red Hat Enterprise Linux (RHEL) Servern betrieben. Die Integration umfasst die Nutzung von `systemd` für die Dienstverwaltung und die Beachtung von Best Practices für Dateisysteme, Netzwerkkonfiguration und Sicherheit.

### Architektur des Clusters
Ein Kafka-Cluster besteht aus:
* Einem oder mehreren **Zookeeper-Servern** (oft ein Quorum von 3 oder 5 für hohe Verfügbarkeit).
* Einem oder mehreren **Kafka-Brokern**.

Die Broker replizieren Topic-Partitionen untereinander, um Fehlertoleranz zu gewährleisten.

### Sicherheitskonzepte
Für den sicheren Betrieb ist **Authentifizierung** (Wer bin ich?) und **Autorisierung** (Was darf ich tun?) entscheidend. In dieser Schulung konzentrieren wir uns auf **JAAS (Java Authentication and Authorization Service)** für die Authentifizierung, oft in Verbindung mit SASL (Simple Authentication and Security Layer) Mechanismen wie `PLAIN` oder `GSSAPI` (Kerberos).

---

## 2. Kafka Cluster Komponenten und deren Status

### Zookeeper
* **Rolle:** Zookeeper ist das Herzstück des Clusters für Metadaten (Broker-IDs, Topic-Konfigurationen, Partition-Leader-Informationen), Leader-Wahlen und die Verfolgung des Cluster-Zustands.
* **Statusprüfung:** Sicherstellen, dass das Zookeeper-Quorum intakt und erreichbar ist.

### Kafka Broker
* **Rolle:** Speichern Nachrichten, verwalten Topic-Partitionen, dienen als Leader oder Follower für Partitionen.
* **Status:** Ein Broker kann `running`, `stopped` oder `failed` sein. Er kann **Leader** für einige Partitionen und **Follower** für andere sein.

### Topics
* **Definition:** Logische Kanäle für Daten.
* **Partitionen:** Physische Einheiten, in die Topics unterteilt sind, ermöglichen Parallelität.
* **Replikationsfaktoren:** Bestimmen, wie oft jede Partition über verschiedene Broker hinweg kopiert wird. Ein Replikationsfaktor von `N` bedeutet `N` Kopien der Daten.

---

## 3. Tägliche Betriebsaufgaben und Überwachung

### Cluster-Gesundheitsprüfung
* **Gesamtstatus:** Sind alle Broker registriert und erreichbar?
* **Broker-Status:** Läuft jeder Broker korrekt?
* **Topic-Status:** Haben alle Partitionen einen aktiven Leader und sind die In-Sync Replicas (ISR) intakt? Ein `Isr` das kleiner als `Replicas` ist, deutet auf potenzielle Probleme hin.

### Client-Verbindungen
* **Erkennen von Produzenten und Konsumenten:** Überprüfen, welche Anwendungen mit dem Cluster verbunden sind und Daten senden/empfangen.
* **Authentifizierung:** Sicherstellen, dass Clients sich erfolgreich authentifizieren können. Authentifizierungsfehler sind ein häufiger Grund für Verbindungsprobleme.

### Consumer Groups und Lags
* **Monitoring des Konsumentenfortschritts:** Überwachen, wie schnell Konsumentengruppen Nachrichten verarbeiten.
* **Lags:** Hohe oder ständig wachsende Lags weisen auf Probleme bei der Nachrichtenverarbeitung hin.

### Ressourcennutzung
* **Server-Ressourcen:** Überwachen von CPU, Speicher, Netzwerk-I/O und Platten-I/O auf allen Broker- und Zookeeper-Servern. Engpässe können die Cluster-Performance erheblich beeinträchtigen.

---

## 4. Neustarts und Wartung

### Geordnete Neustarts von Brokern
* **Wichtigkeit:** Broker sollten immer geordnet neu gestartet werden, um Datenverlust und unnötige Dienstunterbrechungen zu vermeiden.
* **Schritte:**
    1.  Optional: Leader-Migration von Partitionen weg vom neu zu startenden Broker.
    2.  Dienst stoppen.
    3.  Warten, bis verbleibende Broker Leader-Rollen übernommen haben.
    4.  Wartung/Konfigurationsänderungen durchführen.
    5.  Dienst starten.
    6.  Status im Cluster prüfen.

### Umgang mit Ausfällen
* **Broker-Ausfall:** Kafka wählt automatisch neue Leader für die Partitionen des ausgefallenen Brokers, sofern Replicas vorhanden sind.
* **Zookeeper-Ausfall:** Ein Zookeeper-Quorum-Ausfall kann den gesamten Kafka-Cluster lahmlegen, da Metadaten nicht mehr verfügbar sind.

### Topic- und Partitionsverwaltung
* **Hinzufügen/Löschen von Topics:** Vorsicht beim Löschen von Topics, da dies irreversibel ist.
* **Partitionserweiterung:** Die Anzahl der Partitionen eines Topics kann erhöht werden (aber nicht reduziert!).

---

## 5. Fehleranalyse und Troubleshooting

### Log-Analyse
* **Wichtige Log-Dateien:**
    * Kafka Broker Logs (`journalctl -u kafka.service`)
    * Zookeeper Logs (`journalctl -u zookeeper.service`)
    * Anwendungslogs von Produzenten und Konsumenten
* **Log-Muster:** Suchen Sie nach Schlüsselwörtern wie `ERROR`, `WARN`, `Exception`, `Authentication failed`, `Authorization failed`, `Disk full`, `Network`.

### Häufige Probleme
* **Volle Festplatten:** Kafka speichert Nachrichten auf der Festplatte. Volle Platten können zu Schreibfehlern und Cluster-Instabilität führen.
* **Netzwerkprobleme:** Latenz oder Paketverluste können zu Timeouts und Replikationsproblemen führen.
* **Konnektivitätsprobleme:** Clients können sich nicht mit Brokern verbinden.
* **Authentifizierungsfehler:** Falsche JAAS-Konfigurationen, abgelaufene Tickets (Kerberos) oder falsche Benutzerdaten.
* **Autorisierungsfehler:** Fehlende ACLs (Access Control Lists) für Benutzer oder Service-Principals.

### Werkzeuge für die Fehlerbehebung
* **Kafka-interne Tools:** Die `kafka-*-tools.sh` Skripte (siehe Abschnitt 3).
* **OS-Tools:** `top`, `htop`, `free -h`, `df -h`, `iostat`, `netstat`, `ss`, `tcpdump`.

### Wichtige Verzeichnisse und Log-Pfade
* Kafka Installationsverzeichnis: /opt/kafka (oder ähnlich)
* Kafka Konfigurationsdateien: /opt/kafka/config/server.properties
* Kafka Log-Verzeichnisse (Nachrichten): In server.properties unter log.dirs konfiguriert (z.B. /var/lib/kafka/data).
* Zookeeper Datenverzeichnis: In zookeeper.properties unter dataDir konfiguriert (z.B. /var/lib/zookeeper/data).
* Systemd Service-Dateien: /etc/systemd/system/zookeeper.service, /etc/systemd/system/kafka.service
* Java Security Konfiguration für JAAS: z.B. /etc/kafka/conf/kafka_client_jaas.conf
---

## 6. Wichtige Befehle

### systemd
```
sudo systemctl status zookeeper.service
sudo systemctl status kafka.service

sudo systemctl start zookeeper.service
sudo systemctl start kafka.service
```

Alle Kafka-Client-Skripte befinden sich typischerweise im Verzeichnis `./bin` Ihrer Kafka-Installation.

### JAAS-Konfiguration für Kafka Client Befehle

Um Kafka-Client-Befehle mit JAAS-Authentifizierung auszuführen, benötigen Sie eine Konfigurationsdatei.

**Beispiel `client_config.properties`:**
```properties
security.protocol=SASL_SSL # Oder SASL_PLAINTEXT
sasl.mechanism=PLAIN       # Oder GSSAPI, SCRAM-SHA-256 etc.
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="your_username" password="your_password";
```

### Topics
```
Alle Topics auflisten:
./bin/kafka-topics.sh --bootstrap-server localhost:9092 --list --command-config /path/to/client_config.properties

Details zu einem spezifischen Topic anzeigen:
./bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic my_topic_1 --command-config /path/to/client_config.properties

Alle aktiven Consumer Groups auflisten:
./bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list --command-config /path/to/client_config.properties

Details zu einer Consumer Group anzeigen:
./bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group my_consumer_group_1 --command-config /path/to/client_config.properties

```

