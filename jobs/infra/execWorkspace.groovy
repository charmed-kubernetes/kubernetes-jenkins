@Library('juju-pipeline@master') _

def collect_debug_sh = "tox -e py36 -- python3 infra/collect-debug.py"

pipeline {
    agent {
        label "${params.build_node}"
    }
    // Add environment credentials for pyjenkins script on configuring nodes automagically
    environment {
        PATH = "/snap/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin"
    }

    options {
        ansiColor('xterm')
        timestamps()
    }
    stages {
        stage('Running') {
            steps {
                // sh "cd jobs && tox -e py36 -- aws s3 --profile s3 ls s3://jujubigdata"
                // sh "sudo ip link list"
                // sh "which lxc"
                // sh "sudo lxc delete --force piptest || true"
                // sh "sudo lxc profile show default"
                // script {
                //     for (int i = 0; i < 15; i++) {
                //         sh "sudo lxc launch ubuntu:16.04 piptest"
                //         sh "sleep 45"
                //         sh "sudo lxc exec piptest -- /bin/bash -c 'apt-get update' || true"
                //         sh "sudo lxc exec piptest -- /bin/bash -c 'apt-get install -qyf python-pip' || true"
                //         sh "sudo lxc exec piptest -- /bin/bash -c 'pip install requests' || true"
                //         sh "sudo lxc exec piptest -- /bin/bash -c 'pip install sh' || true"
                //         sh "sudo lxc exec piptest -- /bin/bash -c 'pip install launchpadlib' || true"
                //         sh "sudo lxc delete --force piptest"
                //     }
                // }
                // dir("jobs") {
                //     sh "${collect_debug_sh} set-meta"
                //     sh "${collect_debug_sh} starttime"
                //     sh "${collect_debug_sh} test-result --no-fail"
                //     sh "${collect_debug_sh} endtime"
                //     sh "${collect_debug_sh} save-meta"
                //     sh "${collect_debug_sh} push meta.yaml"
                //     sh "${collect_debug_sh} push stats.db"
                // }
                script {
                    if (params.workspace_path) {
                        sh "sudo rm -rf ${params.workspace_path}"
                    }
                    if (params.exec_command) {
                        sh "${params.exec_command}"
                    }
                }
            }
        }
    }
}
