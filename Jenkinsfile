node("mobile-core-install-slave") {
    stage("Checkout") {
      checkout scm
    }

    stage("Run Ansible scripts") {
        def metadata_endpoint = "http://169.254.169.254/latest/meta-data"
        def publicHostName = sh(
                script: "curl -s -v ${metadata_endpoint}/public-hostname",
                returnStdout: true
        ).trim()
        def publicIp = sh(
                script: "curl -s -v ${metadata_endpoint}/public-ipv4",
                returnStdout: true
        ).trim()

        withEnv(["PUBLIC_HOSTNAME=${publicHostName}", "PUBLIC_IP=${publicIp}"]) {
            withCredentials([usernamePassword(credentialsId: 'dockerhubjenkins', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {

                dir("${repoName}") {
                    sh "ansible-galaxy install -r ./installer/requirements.yml"
                    sh "ansible-playbook installer/playbook.yml -e dockerhub_username=${DOCKER_USERNAME} -e dockerhub_password=${DOCKER_PASSWORD} -e cluster_public_hostname=${PUBLIC_HOSTNAME}' -e  'cluster_public_ip=${PUBLIC_IP} --skip-tags install-oc"
                }
            }
        }
    }
}