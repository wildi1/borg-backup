#!/bin/bash

# Preparation
# ===========
# ssh-copy-id [BACKUPUSER]@[BACKUPHOST]
# borg init --encryption=repokey-blake2 /PATH_TO_BACKUP_REPOSITORY

# Execute Command for Cron with Log
# ./borg-backup.sh &> /dev/null 2>&1

# Name of the Script
SCRIPT_NAME="XYZ-Backup"

# Set Pathes spaceseparated what you want to Backup
PATH_TO_BACKUP="/path1 /path2"

# Set Remote Host. Empty for local
REPO_REMOTE_HOST="[BACKUPUSER]@[BACKUPHOST]"

# Set Repository Path on Host (Remote or local)
REPO_PATH="/PATH_TO_BACKUP_REPOSITORY"

#Prefix of the backup. Will be suffixed with datetime
BACKUP_NAME_PREFIX="MY_BACKUP"

# Setting this, so you won't be asked for your repository passphrase:
BORG_PASSPHRASE="XXXX"

# Set Prune Strategy how to keep
PRUNE_KEEP="          \
    --keep-hourly 4   \
    --keep-daily 7    \
    --keep-weekly 4"

function db_backup()
{
    # Run DB Backup here
    info "Starting DB backup"
    # /PATH_TO_DB_BACKUP
}

function main()
{
    CURRENT_TIME=$(date "+%Y-%m-%d-%H-%M-%S")
    BACKUP_NAME="${BACKUP_NAME_PREFIX}-${CURRENT_TIME}"

    export BORG_PASSPHRASE=${BORG_PASSPHRASE}

    # Optional pre running scripts like backups here:
    db_backup

    # Setting this, so the repo does not need to be given on the commandline:
    export BORG_REPO="ssh://${REPO_REMOTE_HOST}/${REPO_PATH}"

    info "Starting Borg backup"

    # Backup the given path with borg
    borg create                         \
        --verbose                       \
        --filter AME                    \
        --list                          \
        --stats                         \
        --show-rc                       \
        --compression lz4               \
        --exclude-caches                \
        ::${BACKUP_NAME}                \
        ${PATH_TO_BACKUP}


    backup_exit=$?

    info "Pruning repository"

    # Use the `prune` subcommand to maintain archives of the repository
    borg prune                             \
        --list                             \
        --prefix "${BACKUP_NAME_PREFIX}"   \
        --show-rc                          \
        ${PRUNE_KEEP}

    prune_exit=$?

    # use highest exit code as global exit code
    global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))

    if [ ${global_exit} -eq 0 ]; then
        info "Backup and Prune finished successfully"
    elif [ ${global_exit} -eq 1 ]; then
        info "Backup and/or Prune finished with warnings"
    else
        info "Backup and/or Prune finished with errors"
    fi

     # Set status.txt and backup log to repository
    if [ -z "${REPO_REMOTE_HOST}" ]
    then
        borg info ${REPO_PATH}::${BACKUP_NAME} | cat > "${REPO_PATH}/status.txt"
        borg check ${REPO_PATH} | cat "${REPO_PATH}/status.txt"
    else
        borg info ${REPO_REMOTE_HOST}:${REPO_PATH}::${BACKUP_NAME} | ssh ${REPO_REMOTE_HOST} "cat > ${REPO_PATH}/status.txt"
        borg check ${REPO_REMOTE_HOST}:${REPO_PATH} | ssh ${REPO_REMOTE_HOST} "cat >> ${REPO_PATH}/status.txt"
        cat ${LOG_PATH} | ssh ${REPO_REMOTE_HOST} "cat > ${REPO_PATH}/backup.log"
    fi

    exit ${global_exit}
}
