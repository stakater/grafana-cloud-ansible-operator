# Grafana Cloud Operator

## Project Overview

The Grafana Cloud Operator is an Ansible-based OpenShift Operator that automates the configuration and management of Grafana OnCall within an OpenShift cluster. This operator simplifies the process of setting up Grafana OnCall, ensuring seamless integration with Alertmanager and consistent alert forwarding.This operator also ensures that dashboards are created for SLO. The operator also ensures proper cleanup of integrations and dashboards.  

### What is Grafana Cloud?

Grafana Cloud is a fully managed observability platform from Grafana Labs, providing a seamless experience across metrics, logs, and traces. Within Grafana Cloud, Grafana OnCall is a dedicated incident response coordination system, directly integrating with Grafana's alerting mechanism to manage on-call schedules, escalations, and incident tracking.

### Problem

Manually configuring Grafana OnCall on a cluster involves several complex steps, including creating accounts, configuring integrations, and editing configurations. This process is time-consuming, error-prone, and can lead to inconsistencies and mis-configurations if not done accurately. Automating these tasks with the Grafana Cloud Operator simplifies the setup, reduces errors, and ensures consistency across clusters.

### SLO Dashboard Management

The Grafana Cloud Operator  supports the creation and management of dashboards that track key Service Level Indicators (SLIs) and ensure compliance with Service Level Objectives (SLOs) for Kubernetes (K8s) and OpenShift environments. This section provides an overview of the SLIs monitored and the SLOs established, along with the automation approach for creating dashboards.

Key SLIs and SLOs Monitored:

- K8s API Uptime
    - SLI: Measures the uptime of the Kubernetes API.
    - SLO: Ensure 99.5% uptime.

- K8s API Request Error Rate
    - SLI: Monitors the error rate of requests made to the Kubernetes API.
    - SLO: Ensure 99.9% success rate.

- OpenShift Console Uptime
    - SLI: Tracks the uptime of the OpenShift web console.

- HAProxy / Router Uptime
    - SLI: Measures the uptime of HAProxy or router services.
  
- OpenShift Authentication Uptime
    - SLI: Monitors the uptime of the OpenShift authentication service.

- Dashboard Organization:
    - Dedicated Folders: Each customer will have a dedicated folder in Grafana Cloud for storing their respective dashboards.
    - One Dashboard per Cluster: Dashboards will be created for each cluster to track these SLIs and ensure they meet the defined SLOs.

### How the Operator Works

#### Operator SDK Framework - Ansible

This operator is built using the Ansible Operator Framework built on Operator SDK, combining the ease of use of Operators with the power of Ansible automation. It reacts to custom resources created within the OpenShift cluster to manage the creation and integration of Grafana OnCall resources with the OpenShift Cluster.

#### Grafana OnCall Integration Process

The Grafana Cloud Operator leverages the flexibility of Ansible in responding to custom resource changes on the cluster, ensuring Grafana OnCall is properly configured and maintained.

#### Workflow

The operator's workflow can be described in two different architectural models:

- **A. Hub and Spoke Model**

    In the Hub-Spoke model, the operator is installed on a central Hub cluster and manages Grafana OnCall configurations for multiple Spoke clusters. This model is ideal for organizations with multiple clusters and aims to centralize monitoring and management.

    ```mermaid
    graph TD

        subgraph "Hub and Spoke Integration with Grafana OnCall and SLO Management"
            subgraph "OpenShift Hub Cluster"
                InitHub[Start: Operation Initiated in Hub]
                GetGCOHub[Get All Config CRs]
                CheckMultipleCRs[Ensure Only One GCC CR Exists]
                GetToken[Retrieve Grafana API Token from Secret]
                ListIntegrations[Fetch List of Existing Integrations in Grafana OnCall]
                FetchClusters[Fetch ManagedClusters]
                FetchSlackChannels[Fetch Slack Channel CRs from All Namespaces]
                DetermineMissingIntegrations[Determine Clusters Missing Integrations]
                CreateIntegration[Create Integration in Grafana OnCall for Missing Clusters]
                CreateSLOFolders[Create SLO Folders in Grafana Cloud]
                CreateSLODashboards[Create SLO Dashboards for Each Cluster]

                InitHub --> GetGCOHub
                GetGCOHub --> CheckMultipleCRs
                CheckMultipleCRs --> GetToken
                GetToken --> ListIntegrations
                ListIntegrations --> FetchClusters
                FetchClusters --> FetchSlackChannels
                FetchSlackChannels --> DetermineMissingIntegrations
                DetermineMissingIntegrations --> CreateIntegration
                DetermineMissingIntegrations --> CreateSLOFolders
                CreateSLOFolders --> CreateSLODashboards
            end

            subgraph "Grafana Cloud"
                GOHub[Grafana OnCall]
                SLOFolders[SLO Folders]
                SLODashboards[SLO Dashboards]
            end

            subgraph "Spoke Clusters"
                SC1[Spoke Cluster 1]
                SC2[Spoke Cluster 2]
                SC3[Spoke Cluster 3]
            end

            subgraph "OpenClusterManagement (OCM)"
                CreateIntegration --> |Create Integration| GOHub
                CreateSLOFolders --> |Create Folders| SLOFolders
                CreateSLODashboards --> |Create Dashboards| SLODashboards
                GOHub -->|Return: Endpoint| RHACM/OCM
                RHACM/OCM --> |ManifestWork| SC1
                RHACM/OCM --> |ManifestWork| SC2
                RHACM/OCM --> |ManifestWork| SC3
            end

        end
    ```

    *Centralized ManagedClusters Monitoring:*
    The operator, installed on the Hub cluster, continually monitors for the presence of ManagedCluster resources from Hive that are registered from Spoke clusters.
    These resources are significant markers, indicating the clusters that require Grafana OnCall integration.

    *Centralized Slack Channel CRs Monitoring:*
    The operator installed on the Hub cluster continually monitors for the presence of Slack Channel resources from Slack Operator that are registered for Spoke clusters.
    The channel resources are present in the same namespace as the Custom Resource generating the ManagedCluster and are attached to the Grafana OnCall integration.

    *Cross-Cluster Grafana OnCall Setup:*
    For each ManagedClusters identified, the operator communicates with the Grafana Cloud's API, initiating the integration process.
    This setup involves creating necessary configurations on Grafana Cloud and retrieving vital details such as the Alertmanager http URL for each respective Spoke cluster.

    *`ManifestWork` Synchronization:*
    Utilizing `ManifestWork` resources from open-cluster-management, the operator ensures that alerting configurations are consistent across all Spoke clusters.
    This mechanism efficiently propagates configuration changes from the Hub to the Spokes, particularly for alert forwarding settings in Alertmanager and Utilizing Watchdog for heartbeats.

    *Centralized Secret Management:*
    The operator centrally manages the `alertmanager-main-generated` secret for each Spoke cluster.
    Through the `ManifestWork`, it disseminates the updated secret configurations, ensuring each Spoke cluster's Alertmanager can successfully forward alerts to Grafana OnCall. Additionally, it adds option for OnCall Heartbeat which acts as a monitoring for monitoring systems. It is utilizing Watchdog for our heartbeats.

    *Forwarding alerts to Slack*
    Fetch Slack Info and Configure Slack, details how the operator additionally configures Grafana OnCall to send alerts directly to a specified Slack channel for enhanced incident awareness and response.
    *Note: This feature utilizes [slack-operator](https://github.com/stakater/slack-operator) which is another one of our open source projects. Please head over there to find detailed information on that operator.*

- **B. Standalone Cluster Model**

    In a standalone cluster model, the operator is installed directly on a single cluster and manages the Grafana OnCall configuration solely for that cluster. This setup is suitable for individual clusters or standalone environments.

    ```mermaid
    graph TD

    subgraph "OpenShift Standalone Cluster"
        Init[Start: Operation Initiated]
        GetClusterName[Retrieve Cluster Name]
        CheckIntegration[Check Grafana Integration Existence]
        CreateIntegration[Create Grafana OnCall Integration]
        ModSecret[Include: modify_alertmanager_secret]
        Reencode[Re-encode Alertmanager Content]
        PatchSecret[Patch alertmanager-main Secret]
        UpdateCR[Update CR Status to ConfigUpdated]
        CreateSLOFolder[Create SLO Folder in Grafana Cloud]
        CreateSLODashboard[Create SLO Dashboard in Grafana Cloud]

        Init --> GetClusterName
        GetClusterName --> CheckIntegration
        CheckIntegration -->|Integration doesn't exist| CreateIntegration
        CheckIntegration -->|Integration exists| UpdateCR
        CreateIntegration --> FetchSlackInfo
        FetchSlackInfo --> ConfigureSlack
        ConfigureSlack --> ModSecret
        ModSecret --> Reencode
        Reencode --> PatchSecret
        PatchSecret --> UpdateCR
        CreateIntegration --> CreateSLOFolder
        CreateSLOFolder --> CreateSLODashboard
    end

    subgraph "Grafana Cloud"
        GO[Grafana OnCall]
    end

    ConfigureSlack -->|API Call: Configure Slack| GO
    GO -->|Return: Endpoint| ConfigureSlack
    ```

    *Operator Workflow in Standalone Cluster:*
    The operator functions within the single OpenShift cluster, monitoring  resources that indicate the local cluster's need for Grafana OnCall integration.

    *Direct Grafana OnCall Setup:*
    Upon identifying the GCC CR, described in the next section, the operator proceeds with the Grafana OnCall setup by interacting with Grafana Cloud's API.
    It establishes the necessary integrations and secures essential details, including the Alertmanager http URL.

    *In-Cluster Configuration Management:*
    The operator directly applies configuration changes within the cluster, bypassing the need for `ManifestWork`.
    It ensures the Alertmanager's alert forwarding settings are correctly configured for seamless communication with Grafana OnCall. Additionally, it adds option for On call Heartbeat which acts as a monitoring for monitoring systems using Watchdog.

    *Local Secret Management:*
    Managing the `alertmanager-main-generated` secret locally, the operator updates its configurations.
    This update enables the Alertmanager within the standalone cluster to route alerts effectively to Grafana OnCall, completing the integration process.

    *Forwarding alerts to Slack*
    Just like the hub-and-spoke model, Slack channel can be configured in Standalone mode by populating the `slackId` field , this additionally, configures Grafana OnCall to send alerts directly to a specified Slack channel for enhanced incident awareness and response.
    *Note: This feature utilizes [slack-operator](https://github.com/stakater/slack-operator) which is another one of our open source projects. Please head over there to find detailed information on that operator.*

### Prerequisites

- An OpenShift cluster up and running.
- `oc` CLI tool.
- Access to Grafana OnCall's API key with relevant permissions.

### Installation

This section outlines the process of installing the Grafana Cloud Operator through a custom catalog as well as helm charts. By following these steps, you will be able to deploy the operator on a cluster.

#### Install Using Custom Catalog

1. **Create a Namespace**

    Start by creating a specific namespace for the Grafana Cloud Operator.

    ```bash
    oc create namespace grafana-cloud-operator
    ```

1. **Create a Secret Called `saap-dockerconfigjson`**

    Since the catalog image is private, you need to create a secret that contains your Docker credentials. This secret is necessary to pull the catalog image from the GitHub Container Registry.

    ```bash
    oc -n grafana-cloud-operator create secret docker-registry saap-dockerconfigjson \
    --docker-server=ghcr.io \
    --docker-username=<username> \
    --docker-password=<your-access-token> \
    --docker-email=<email>
    ```

    *Note: Replace `username`, `your-access-token`, and `email` with your GitHub username, a personal access token (with `read:packages` scope enabled), and your email, respectively.*

1. **Create Grafana API Token Secret**

    The operator needs to interact with the Grafana Cloud's APIs, and for this, it requires an API token. Create a secret to store this token securely.

    ```bash
    oc -n grafana-cloud-operator create secret generic grafana-api-token-secret \
    --from-literal=api-token=<your-grafana-api-token>
    ```

    *Note: Obtain the API token from your Grafana OnCall settings page and replace <your-grafana-api-token> with your actual API token.*

1. **Apply the Custom Catalog Source**
    Now, apply the [custom catalog](./custom-catalog.yaml) source configuration to your cluster. This catalog source contains the operator that you wish to install.

    ```bash
    oc -n grafana-cloud-operator create -f custom-catalog.yaml
    ```

    *Note: Ensure that `custom-catalog.yaml` is properly configured with the right details of your custom catalog.*

1. **Install the Operator via OperatorHub**

    Navigate to the OperatorHub in your OpenShift console. Search for "Grafana Cloud Operator" and proceed with the installation by following the on-screen instructions. Select the `grafana-cloud-operator` namespace for deploying the operator.

1. **Verify the Installation**

    After the installation, ensure that the operator's components are running properly. Check the status of the pods with the following command:

    ```bash
    oc -n grafana-cloud-operator get pods
    ```

    You should see the operator pod in a Running state.

#### Install using helm charts

1. **Create a Namespace**

    We need a separate namespace for Grafana Cloud Operator to keep things organized and isolated.

    ```bash
    oc create namespace grafana-cloud-operator
    ```

1. **Create a Docker Registry Secret**
    This secret is required to pull the operator image from a private registry. Without it, the cluster won't be able to access the images, and the deployment will fail.

    ```bash
    oc -n grafana-cloud-operator create secret docker-registry saap-dockerconfigjson \
    --docker-server=ghcr.io \
    --docker-username=<username> \
    --docker-password=<your-access-token> \
    --docker-email=<email>
    ```

    *Note: Make sure to replace `username`, `your-access-token`, and `email` with your actual information. The access token should have the appropriate permissions to read from the container registry.*

1. **Create a Grafana API Token Secret**

    The Grafana Cloud Operator interacts with Grafana Cloud's APIs. As such, it requires an API token, which should be stored as a Kubernetes secret.

    ```bash
    oc -n grafana-cloud-operator create secret generic grafana-api-token-secret \
    --from-literal=api-token=<your-grafana-api-token>
    ```

    *Note: Replace <your-grafana-api-token> with your actual Grafana API token. You can generate/find this token in your Grafana OnCall settings page.*

1. **Install the Grafana Cloud Operator Using Helm**

    Now you're set to install the Grafana Cloud Operator using Helm. Run the following command, making sure to replace <chart-path> with the path to your Helm chart. This command installs the Helm chart with the release name `grafana-cloud-operator` in the `grafana-cloud-operator` namespace.

    ```bash
    helm install grafana-cloud-operator <chart-path> --namespace grafana-cloud-operator
    ```

    *Note: The default <chart-path> is `charts/grafana-oncall` from the root of the repo.*

1. **Verify the Installation**

    Check if all the pods related to the Grafana Cloud Operator are up and running.

    ```bash
    oc -n grafana-cloud-operator get pods
    ```

    This command will list the pods in the `grafana-cloud-operator` namespace, allowing you to verify their status. Ensure that all pods are either in the Running or Completed state, indicating that they are operational.

    This Helm-based approach simplifies the deployment of the Grafana Cloud Operator by encapsulating the configuration details. Users can easily upgrade or rollback the operator, leveraging Helm's package management capabilities.

### Quick Start

After installation, you can create a `Config` resource by applying the below CRD that the operator recognizes.

The operator gets its instructions from a custom resource (CR) that follows the `Config` Custom Resource Definition (CRD). This CR contains all the necessary information, from the API token required to interact with Grafana Cloud to the mode of operation the operator should adopt.

Here's a step-by-step guide on understanding and applying this configuration:

1. Preparing Your Custom Resource:

    First, let's break down the essential parts of the CR:

    ```yaml
    apiVersion: grafanacloud.stakater.com/v1alpha1
    kind: Config
    metadata:
      name: config-sample  # This is a user-defined name for your custom resource
      namespace: grafana-cloud-operator  # Namespace where the operator is installed
    spec:
      enabled: true # Flag to disable dashboard creation on grafana cloud
      sloObservabilityURL: https://raw.githubusercontent.com/stakater/charts/slo-observability-0.0.9 # URL of SLO Dashboard that needs to be used
      sloCloudAPI: https://grafana.net/api # Api URL for SLO Dashboards
      sloDashboardAPIToken:
        key: api-token  # The key field within the secret holding the Dashboard API token
        secretName: slo-dashboard-api-token-secret # The name of the Kubernetes secret storing the Dashboard API token
      grafanaAPIToken:
        key: api-token  # The key field within the secret holding the Grafana OnCall API token
        secretName: grafana-api-token-secret  # The name of the Kubernetes secret storing the Grafana OnCall API token
      slackId: C0DDD0ZD4JZ # For Standalone mode populate this field to connect Slack Channel to Grafana OnCall Integration
      slack: true # Slack alerts toggle for integration. This would disable sending of alerts to the channel. By default, it set to true
      provisionMode: standalone  # Determines the mode of operation - 'hubAndSpoke' or 'standaloneCluster'
    ```

    - `metadata`: Contains general information about the custom resource that you are creating, such as its name and the namespace it resides in.
    - `spec`: This is where the bulk of the configuration goes. It's broken down further below:
      - `enabled`: Flag to disable dashboard creation on Grafana Cloud.
      - `sloCloudAPI`: API for Grafana Dashboard
      - `sloObservabilityVersion`: You can use this field to use any available release for the SLO Dashboards
      - `sloDashboardAPIToken`: Since the operator needs to interact with Grafana Dashboards API, you need to provide it with an API token. This token is stored within a Kubernetes secret for security, and here you point the operator to the right secret and key.
      - `grafanaAPIToken`: Since the operator needs to interact with Grafana OnCall's API, you need to provide it with an API token. This token is stored within a Kubernetes secret for security, and here you point the operator to the right secret and key.
      - `provisionMode`: Indicates how the operator should function. It could be in a 'hubAndSpoke' mode where it manages multiple clusters or `standaloneCluster` for managing a single cluster.
      - `slackId`: For `standalone` provision mode populate this field to connect Slack Channel to Grafana OnCall Integration.
      - `slack`: This is toggle for slack alerts to channel. It accepts boolean. By default, it set to true.

1. Applying the Custom Resource:

    Once your custom resource is ready and tailored for your specific use case, you need to apply it within your OpenShift environment. This action tells the operator what it should do.

    ```bash
    oc apply -f your-config-file.yaml
    ```

1. Modes of Operation:

    The `provisionMode` in the spec can be one of the following two values:

    - `hubAndSpoke`: Use this when you have the operator installed on a central Hub cluster, and you intend for it to manage Grafana OnCall integrations on multiple Spoke clusters.
    - `standaloneCluster`: This is used when the operator is handling Grafana OnCall integration for a single cluster, where it's installed and operated.

    Here's how you would set the `provisionMode` for a standalone cluster:

    ```yaml
    spec:
      provisionMode: standaloneCluster
    ```

    The operator adapts its behavior based on this directive, ensuring that your Grafana OnCall integrations are set up and managed in a way that's optimal for your organizational architecture and needs.

### Automated Resource Cleanup

The Grafana Cloud Operator includes a robust deletion mechanism that not only handles dashboards but also integrations in Grafana Cloud. This feature ensures outdated or unnecessary resources are efficiently removed, maintaining an organized and optimal environment.

#### How the Deletion Mechanism Works

- ManagedCluster Monitoring: The operator actively watches ManagedClusters to detect changes or deletions. This ensures that resources associated with deleted or modified clusters are identified for removal.
- Identification of Outdated Resources:
    - Dashboards: Retrieves unique identifiers `(UIDs)` for dashboards linked to ManagedClusters to target for deletion.
    - Integrations: Collects identifiers for integrations tied to ManagedClusters to accurately manage their lifecycle.
- Automated Deletion: Once outdated or deleted ManagedClusters are detected, the operator sends DELETE requests to the Grafana Cloud API to remove the associated dashboards and integrations.
- Error Handling: Built-in error handling manages scenarios where resources may have already been deleted or do not exist, preventing unnecessary failures.

#### Benefits of the ManagedCluster-Based Deletion

- Automated Cleanup: Ensures dashboards and integrations tied to ManagedClusters are cleaned up automatically, reducing manual intervention.
- Resource Optimization: Helps maintain a lean Grafana Cloud environment by removing unused resources, improving performance and manageability.
- Smooth Integration with Playbooks: The deletion process can be integrated with Ansible playbooks for a comprehensive orchestration logic.

### Monitoring and Troubleshooting

After you've applied the CR, the operator starts performing its duties based on the instructions given. You can monitor the operator's activities and troubleshoot potential issues by examining the logs of the operator pod:

```bash
oc -n grafana-cloud-operator logs -f <operator-pod-name>
```

This command will stream the logs from the operator to your console, providing real-time updates on what the operator is doing. It's crucial for identifying any problems the operator encounters while trying to set up Grafana OnCall.

### Have a Question?

File a GitHub [issue](https://github.com/stakater/grafana-cloud-ansible-operator/issues).

### Talk to Us on Slack

Join and talk to us on Slack for discussing Reloader

[![Join Slack](https://stakater.github.io/README/stakater-join-slack-btn.png)](https://stakater.slack.com/)
[![Chat](https://stakater.github.io/README/stakater-chat-btn.png)](https://stakater-community.slack.com/messages/CC5S05S12)

### Contributing

### Bug Reports & Feature Requests

Please use the [issue tracker](https://github.com/stakater/grafana-cloud-ansible-operator/issues) to report any bugs or file feature requests.

## License

Apache2 © [Stakater][website]

## About

`Grafana Cloud Ansible Operator` is maintained by [Stakater][website]. Like it? Please let us know at `hello@stakater.com`

See [our other projects](https://github.com/stakater)
or contact us in case of professional services and queries on `hello@stakater.com`

[website]: https://stakater.com
