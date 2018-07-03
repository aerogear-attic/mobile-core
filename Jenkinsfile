// https://github.com/feedhenry/fh-pipeline-library
@Library('fh-pipeline-library') _

@NonCPS
String sanitizeObjectName(String s) {
    s.replace('_', '-')
        .replace('.', '-')
        .toLowerCase()
        .reverse()
        .take(23)
        .replaceAll("^-+", "")
        .reverse()
        .replaceAll("^-+", "")
}

stage('Trust') {
    enforceTrustedApproval('aerogear')
}

node("mobile-core-test") {
    step([$class: 'WsCleanup'])

    stage("Checkout") {
      checkout scm
    }

    stage("Cleanup") {
       sh "make clean"
    }
    catchError {
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
                    sh "ansible-galaxy install -r ./installer/requirements.yml"
                    def args = "-e dockerhub_username=${DOCKER_USERNAME} -e dockerhub_password=${DOCKER_PASSWORD}"
                    args += " -e cluster_public_hostname=${PUBLIC_HOSTNAME} -e cluster_public_ip=${PUBLIC_IP}"
                    args += " -e '{cluster_local_instance: no}'"
                    sh "ansible-playbook installer/playbook.yml ${args} --skip-tags install-oc --verbose"
                }
            }
        }
    }  
}

