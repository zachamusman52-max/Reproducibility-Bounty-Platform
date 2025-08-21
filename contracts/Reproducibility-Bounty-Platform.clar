(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_STUDY_NOT_FOUND (err u404))
(define-constant ERR_INSUFFICIENT_BOUNTY (err u400))
(define-constant ERR_STUDY_ALREADY_EXISTS (err u409))
(define-constant ERR_REPLICATION_NOT_FOUND (err u404))
(define-constant ERR_INVALID_STATUS (err u422))
(define-constant ERR_ALREADY_REPLICATED (err u409))
(define-constant ERR_INSUFFICIENT_FUNDS (err u402))

(define-constant STUDY_STATUS_ACTIVE u1)
(define-constant STUDY_STATUS_COMPLETED u2)
(define-constant STUDY_STATUS_CANCELLED u3)

(define-constant REPLICATION_STATUS_PENDING u1)
(define-constant REPLICATION_STATUS_VERIFIED u2)
(define-constant REPLICATION_STATUS_REJECTED u3)

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
    successful-replications: uint
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
    reviewer: (optional principal)
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
        successful-replications: u0
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
        reviewer: none
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
