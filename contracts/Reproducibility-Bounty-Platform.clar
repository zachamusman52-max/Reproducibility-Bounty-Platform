(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_STUDY_NOT_FOUND (err u404))
(define-constant ERR_INSUFFICIENT_BOUNTY (err u400))
(define-constant ERR_STUDY_ALREADY_EXISTS (err u409))
(define-constant ERR_REPLICATION_NOT_FOUND (err u404))
(define-constant ERR_INVALID_STATUS (err u422))
(define-constant ERR_ALREADY_REPLICATED (err u409))
(define-constant ERR_INSUFFICIENT_FUNDS (err u402))
(define-constant ERR_NOT_COLLABORATOR (err u403))
(define-constant ERR_ALREADY_COLLABORATOR (err u410))
(define-constant ERR_MAX_COLLABORATORS_REACHED (err u411))

(define-constant STUDY_STATUS_ACTIVE u1)
(define-constant STUDY_STATUS_COMPLETED u2)
(define-constant STUDY_STATUS_CANCELLED u3)

(define-constant REPLICATION_STATUS_PENDING u1)
(define-constant REPLICATION_STATUS_VERIFIED u2)
(define-constant REPLICATION_STATUS_REJECTED u3)

(define-constant MAX_COLLABORATORS u5)
(define-constant MIN_COLLABORATOR_APPROVALS u2)

(define-data-var study-counter uint u0)
(define-data-var replication-counter uint u0)

(define-map studies
  { study-id: uint }
  {
    researcher: principal,
    title: (string-ascii 256),
    description: (string-ascii 1024),
    methodology: (string-ascii 2048),
    bounty-amount: uint,
    created-at: uint,
    status: uint,
    replications-count: uint,
    successful-replications: uint,
    collaborators-count: uint
  }
)

(define-map replications
  { replication-id: uint }
  {
    study-id: uint,
    replicator: principal,
    findings: (string-ascii 1024),
    data-hash: (buff 32),
    created-at: uint,
    verified-at: (optional uint),
    status: uint,
    reviewer: (optional principal),
    approvals-count: uint
  }
)

(define-map user-studies
  { user: principal, study-id: uint }
  { is-owner: bool }
)

(define-map user-replications
  { user: principal, replication-id: uint }
  { is-replicator: bool }
)

(define-map study-replications
  { study-id: uint, replicator: principal }
  { replication-id: uint }
)

(define-map study-collaborators
  { study-id: uint, collaborator: principal }
  { invited-at: uint, is-active: bool }
)

(define-map replication-approvals
  { replication-id: uint, approver: principal }
  { approved-at: uint, is-successful: bool }
)

(define-public (create-study (title (string-ascii 256)) (description (string-ascii 1024)) (methodology (string-ascii 2048)) (bounty-amount uint))
  (let 
    (
      (new-study-id (+ (var-get study-counter) u1))
      (current-block (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (asserts! (> bounty-amount u0) ERR_INSUFFICIENT_BOUNTY)
    (try! (stx-transfer? bounty-amount tx-sender (as-contract tx-sender)))
    (map-set studies 
      { study-id: new-study-id }
      {
        researcher: tx-sender,
        title: title,
        description: description,
        methodology: methodology,
        bounty-amount: bounty-amount,
        created-at: current-block,
        status: STUDY_STATUS_ACTIVE,
        replications-count: u0,
        successful-replications: u0,
        collaborators-count: u0
      }
    )
    (map-set user-studies
      { user: tx-sender, study-id: new-study-id }
      { is-owner: true }
    )
    (var-set study-counter new-study-id)
    (ok new-study-id)
  )
)

(define-public (submit-replication (study-id uint) (findings (string-ascii 1024)) (data-hash (buff 32)))
  (let
    (
      (study-data (unwrap! (map-get? studies { study-id: study-id }) ERR_STUDY_NOT_FOUND))
      (new-replication-id (+ (var-get replication-counter) u1))
      (current-block (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (asserts! (is-eq (get status study-data) STUDY_STATUS_ACTIVE) ERR_INVALID_STATUS)
    (asserts! (is-none (map-get? study-replications { study-id: study-id, replicator: tx-sender })) ERR_ALREADY_REPLICATED)
    (map-set replications
      { replication-id: new-replication-id }
      {
        study-id: study-id,
        replicator: tx-sender,
        findings: findings,
        data-hash: data-hash,
        created-at: current-block,
        verified-at: none,
        status: REPLICATION_STATUS_PENDING,
        reviewer: none,
        approvals-count: u0
      }
    )
    (map-set user-replications
      { user: tx-sender, replication-id: new-replication-id }
      { is-replicator: true }
    )
    (map-set study-replications
      { study-id: study-id, replicator: tx-sender }
      { replication-id: new-replication-id }
    )
    (map-set studies
      { study-id: study-id }
      (merge study-data { replications-count: (+ (get replications-count study-data) u1) })
    )
    (var-set replication-counter new-replication-id)
    (ok new-replication-id)
  )
)

(define-public (invite-collaborator (study-id uint) (collaborator principal))
  (let
    (
      (study-data (unwrap! (map-get? studies { study-id: study-id }) ERR_STUDY_NOT_FOUND))
      (current-block (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (asserts! (is-eq tx-sender (get researcher study-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status study-data) STUDY_STATUS_ACTIVE) ERR_INVALID_STATUS)
    (asserts! (< (get collaborators-count study-data) MAX_COLLABORATORS) ERR_MAX_COLLABORATORS_REACHED)
    (asserts! (is-none (map-get? study-collaborators { study-id: study-id, collaborator: collaborator })) ERR_ALREADY_COLLABORATOR)
    (map-set study-collaborators
      { study-id: study-id, collaborator: collaborator }
      { invited-at: current-block, is-active: true }
    )
    (map-set studies
      { study-id: study-id }
      (merge study-data { collaborators-count: (+ (get collaborators-count study-data) u1) })
    )
    (ok true)
  )
)

(define-public (remove-collaborator (study-id uint) (collaborator principal))
  (let
    (
      (study-data (unwrap! (map-get? studies { study-id: study-id }) ERR_STUDY_NOT_FOUND))
      (collaborator-data (unwrap! (map-get? study-collaborators { study-id: study-id, collaborator: collaborator }) ERR_NOT_COLLABORATOR))
    )
    (asserts! (is-eq tx-sender (get researcher study-data)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active collaborator-data) ERR_NOT_COLLABORATOR)
    (map-set study-collaborators
      { study-id: study-id, collaborator: collaborator }
      (merge collaborator-data { is-active: false })
    )
    (map-set studies
      { study-id: study-id }
      (merge study-data { collaborators-count: (- (get collaborators-count study-data) u1) })
    )
    (ok true)
  )
)

(define-public (approve-replication (replication-id uint) (is-successful bool))
  (let
    (
      (replication-data (unwrap! (map-get? replications { replication-id: replication-id }) ERR_REPLICATION_NOT_FOUND))
      (study-data (unwrap! (map-get? studies { study-id: (get study-id replication-data) }) ERR_STUDY_NOT_FOUND))
      (current-block (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (collaborator-data (map-get? study-collaborators { study-id: (get study-id replication-data), collaborator: tx-sender }))
      (is-researcher (is-eq tx-sender (get researcher study-data)))
      (is-active-collaborator (match collaborator-data
        data (get is-active data)
        false
      ))
      (can-approve (or is-researcher is-active-collaborator))
    )
    (asserts! can-approve ERR_NOT_COLLABORATOR)
    (asserts! (is-eq (get status replication-data) REPLICATION_STATUS_PENDING) ERR_INVALID_STATUS)
    (asserts! (is-none (map-get? replication-approvals { replication-id: replication-id, approver: tx-sender })) ERR_ALREADY_REPLICATED)
    (map-set replication-approvals
      { replication-id: replication-id, approver: tx-sender }
      { approved-at: current-block, is-successful: is-successful }
    )
    (let
      (
        (new-approvals-count (+ (get approvals-count replication-data) u1))
        (bounty-per-replication (/ (get bounty-amount study-data) u10))
        (should-finalize (and 
          is-successful 
          (>= new-approvals-count MIN_COLLABORATOR_APPROVALS)
          (> (get collaborators-count study-data) u0)
        ))
      )
      (map-set replications
        { replication-id: replication-id }
        (merge replication-data { approvals-count: new-approvals-count })
      )
      (if should-finalize
        (begin
          (try! (as-contract (stx-transfer? bounty-per-replication tx-sender (get replicator replication-data))))
          (map-set replications
            { replication-id: replication-id }
            (merge replication-data 
              {
                status: REPLICATION_STATUS_VERIFIED,
                verified-at: (some current-block),
                reviewer: (some tx-sender),
                approvals-count: new-approvals-count
              }
            )
          )
          (map-set studies
            { study-id: (get study-id replication-data) }
            (merge study-data { successful-replications: (+ (get successful-replications study-data) u1) })
          )
        )
        (if (and (not is-successful) (>= new-approvals-count MIN_COLLABORATOR_APPROVALS))
          (map-set replications
            { replication-id: replication-id }
            (merge replication-data 
              {
                status: REPLICATION_STATUS_REJECTED,
                verified-at: (some current-block),
                reviewer: (some tx-sender),
                approvals-count: new-approvals-count
              }
            )
          )
          true
        )
      )
      (ok is-successful)
    )
  )
)

(define-public (verify-replication (replication-id uint) (is-successful bool))
  (let
    (
      (replication-data (unwrap! (map-get? replications { replication-id: replication-id }) ERR_REPLICATION_NOT_FOUND))
      (study-data (unwrap! (map-get? studies { study-id: (get study-id replication-data) }) ERR_STUDY_NOT_FOUND))
      (current-block (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (bounty-per-replication (/ (get bounty-amount study-data) u10))
    )
    (asserts! (is-eq tx-sender (get researcher study-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status replication-data) REPLICATION_STATUS_PENDING) ERR_INVALID_STATUS)
    (if is-successful
      (begin
        (try! (as-contract (stx-transfer? bounty-per-replication tx-sender (get replicator replication-data))))
        (map-set replications
          { replication-id: replication-id }
          (merge replication-data 
            {
              status: REPLICATION_STATUS_VERIFIED,
              verified-at: (some current-block),
              reviewer: (some tx-sender)
            }
          )
        )
        (map-set studies
          { study-id: (get study-id replication-data) }
          (merge study-data { successful-replications: (+ (get successful-replications study-data) u1) })
        )
      )
      (map-set replications
        { replication-id: replication-id }
        (merge replication-data 
          {
            status: REPLICATION_STATUS_REJECTED,
            verified-at: (some current-block),
            reviewer: (some tx-sender)
          }
        )
      )
    )
    (ok is-successful)
  )
)

(define-public (cancel-study (study-id uint))
  (let
    (
      (study-data (unwrap! (map-get? studies { study-id: study-id }) ERR_STUDY_NOT_FOUND))
      (refund-amount (get bounty-amount study-data))
    )
    (asserts! (is-eq tx-sender (get researcher study-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status study-data) STUDY_STATUS_ACTIVE) ERR_INVALID_STATUS)
    (try! (as-contract (stx-transfer? refund-amount tx-sender (get researcher study-data))))
    (map-set studies
      { study-id: study-id }
      (merge study-data { status: STUDY_STATUS_CANCELLED })
    )
    (ok true)
  )
)

(define-public (withdraw-remaining-bounty (study-id uint))
  (let
    (
      (study-data (unwrap! (map-get? studies { study-id: study-id }) ERR_STUDY_NOT_FOUND))
      (total-paid (* (get successful-replications study-data) (/ (get bounty-amount study-data) u10)))
      (remaining-amount (- (get bounty-amount study-data) total-paid))
    )
    (asserts! (is-eq tx-sender (get researcher study-data)) ERR_NOT_AUTHORIZED)
    (asserts! (or (is-eq (get status study-data) STUDY_STATUS_ACTIVE) (is-eq (get status study-data) STUDY_STATUS_COMPLETED)) ERR_INVALID_STATUS)
    (asserts! (> remaining-amount u0) ERR_INSUFFICIENT_FUNDS)
    (try! (as-contract (stx-transfer? remaining-amount tx-sender (get researcher study-data))))
    (map-set studies
      { study-id: study-id }
      (merge study-data { status: STUDY_STATUS_COMPLETED })
    )
    (ok remaining-amount)
  )
)

(define-read-only (get-study (study-id uint))
  (map-get? studies { study-id: study-id })
)

(define-read-only (get-replication (replication-id uint))
  (map-get? replications { replication-id: replication-id })
)

(define-read-only (get-study-stats (study-id uint))
  (match (map-get? studies { study-id: study-id })
    study-data 
      (some {
        total-replications: (get replications-count study-data),
        successful-replications: (get successful-replications study-data),
        success-rate: (if (> (get replications-count study-data) u0)
          (/ (* (get successful-replications study-data) u100) (get replications-count study-data))
          u0
        ),
        remaining-bounty: (- (get bounty-amount study-data) (* (get successful-replications study-data) (/ (get bounty-amount study-data) u10)))
      })
    none
  )
)

(define-read-only (get-user-replication-for-study (study-id uint) (user principal))
  (match (map-get? study-replications { study-id: study-id, replicator: user })
    replication-mapping (map-get? replications { replication-id: (get replication-id replication-mapping) })
    none
  )
)

(define-read-only (get-platform-stats)
  {
    total-studies: (var-get study-counter),
    total-replications: (var-get replication-counter),
    current-block: (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1)))
  }
)

(define-read-only (is-study-owner (study-id uint) (user principal))
  (is-some (map-get? user-studies { user: user, study-id: study-id }))
)

(define-read-only (is-replication-author (replication-id uint) (user principal))
  (is-some (map-get? user-replications { user: user, replication-id: replication-id }))
)

(define-read-only (is-study-collaborator (study-id uint) (user principal))
  (match (map-get? study-collaborators { study-id: study-id, collaborator: user })
    data (get is-active data)
    false
  )
)

(define-read-only (get-study-collaborators-info (study-id uint))
  (match (map-get? studies { study-id: study-id })
    study-data 
      (some {
        collaborators-count: (get collaborators-count study-data),
        max-collaborators: MAX_COLLABORATORS,
        min-approvals-required: MIN_COLLABORATOR_APPROVALS
      })
    none
  )
)

(define-read-only (get-replication-approval-status (replication-id uint))
  (match (map-get? replications { replication-id: replication-id })
    replication-data
      (some {
        current-approvals: (get approvals-count replication-data),
        required-approvals: MIN_COLLABORATOR_APPROVALS,
        status: (get status replication-data)
      })
    none
  )
)
