pipeline {
    agent {
        label "runner-amd64"
    }
    /* XXX: Global $PATH setting doesn't translate properly in pipelines
     https://stackoverflow.com/questions/43987005/jenkins-does-not-recognize-command-sh
     */
    environment {
        PATH                 = "/var/lib/jenkins/venvs/ci/bin:/snap/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin"
        JUJU_CLOUD           = "aws/us-east-1"
        CHARMCRAFT_AUTH      = credentials('charm_creds')
        NOTIFY_EMAIL         = credentials('microk8s_notify_email')
    }
    options {
        ansiColor('xterm')
        timestamps()
    }
    stages {
        stage("Setup tox environment") {
            steps {
                sh """
                tox -c jobs/microk8s/tox.ini -e py38 -- python -c 'print("Tox Environment Ready")'
                """
            }
        }
        stage("Run Release Steps") {
            steps {
                script {
                    def job="release-microk8s-charm"
                    def juju_controller="${job}"
                    def juju_model="${job}-model"

                    sh destroy_controller(juju_controller)
                    sh """#!/bin/bash -x
                    juju bootstrap "${JUJU_CLOUD}" "${juju_controller}" \
                        -d "${juju_model}" \
                        --model-default test-mode=true \
                        --model-default resource-tags="owner=k8sci job=${job} stage=${stage}" \
                        --bootstrap-constraints "mem=8G cores=2"
                    """
                    try {
                        sh """
                        . jobs/microk8s/.tox/py38/bin/activate
                        DRY_RUN=${params.DRY_RUN} SKIP_TESTS=${params.SKIP_TESTS}\
                            BRANCH=${params.TESTS_BRANCH} REPOSITORY=${params.TESTS_REPOSITORY}\
                            CONTROLLER=${juju_controller}\
                            timeout 6h python jobs/microk8s/charms/release.py
                        """
                    } catch (err) {
                        unstable("Completed with errors.")
                        emailext(
                                    to: env.NOTIFY_EMAIL,
                                    subject: "Job '${JOB_NAME}' (${BUILD_NUMBER}) failed",
                                    body: "Please go to ${BUILD_URL} and verify the build"
                        )
                    } finally {
                        sh destroy_controller(juju_controller)
                    }
                }
            }
        }
    }
    post {
        always {
            script {
                def job="release-microk8s-charm"
                def juju_controller="${job}"
                sh destroy_controller(juju_controller)
            }
        }
    }
}
