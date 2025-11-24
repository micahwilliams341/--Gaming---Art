(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_SONG_NOT_FOUND (err u404))
(define-constant ERR_INVALID_PERCENTAGE (err u400))
(define-constant ERR_PARTICIPANT_NOT_FOUND (err u405))
(define-constant ERR_INSUFFICIENT_BALANCE (err u406))
(define-constant ERR_SONG_ALREADY_EXISTS (err u407))
(define-constant ERR_INVALID_PARTICIPANT (err u408))
(define-constant ERR_BATCH_PROCESSING_FAILED (err u409))
(define-constant ERR_TRANSFER_TO_SELF (err u410))
(define-constant ERR_INVALID_NEW_OWNER (err u411))
(define-constant TOTAL_PERCENTAGE u10000)

(define-data-var song-counter uint u0)
(define-data-var total-earnings uint u0)

(define-map songs
  { song-id: uint }
  { 
    title: (string-ascii 100),
    creator: principal,
    total-earned: uint,
    is-active: bool
  }
)

(define-map royalty-splits
  { song-id: uint, participant: principal }
  { 
    percentage: uint,
    role: (string-ascii 50),
    earned: uint
  }
)

(define-map song-participants
  { song-id: uint }
  { participants: (list 20 principal) }
)

(define-map user-earnings
  { user: principal }
  { total-earned: uint, withdrawn: uint }
)

(define-map song-ownership-history
  { song-id: uint, transfer-id: uint }
  { 
    previous-owner: principal,
    new-owner: principal,
    transfer-timestamp: uint
  }
)

(define-map song-transfer-count
  { song-id: uint }
  { count: uint }
)

(define-public (create-song (title (string-ascii 100)) (participants (list 20 { participant: principal, percentage: uint, role: (string-ascii 50) })))
  (let (
    (song-id (+ (var-get song-counter) u1))
    (total-percentage (fold + (map get-percentage participants) u0))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq total-percentage TOTAL_PERCENTAGE) ERR_INVALID_PERCENTAGE)
    (asserts! (> (len participants) u0) ERR_INVALID_PARTICIPANT)
    
    (map-set songs
      { song-id: song-id }
      {
        title: title,
        creator: tx-sender,
        total-earned: u0,
        is-active: true
      }
    )
    
    (fold set-participant-for-song participants { song-id: song-id, success: true })
    (map-set song-participants 
      { song-id: song-id }
      { participants: (map get-participant-address participants) }
    )
    
    (var-set song-counter song-id)
    (ok song-id)
  )
)

(define-public (distribute-royalties (song-id uint) (amount uint))
  (let (
    (song (unwrap! (map-get? songs { song-id: song-id }) ERR_SONG_NOT_FOUND))
    (participants (default-to (list) (get participants (map-get? song-participants { song-id: song-id }))))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active song) ERR_SONG_NOT_FOUND)
    (asserts! (> amount u0) ERR_INSUFFICIENT_BALANCE)
    
    (fold update-participant-earnings-fold participants { song-id: song-id, total-amount: amount, success: true })
    (map-set songs
      { song-id: song-id }
      (merge song { total-earned: (+ (get total-earned song) amount) })
    )
    
    (var-set total-earnings (+ (var-get total-earnings) amount))
    (ok amount)
  )
)

(define-public (batch-distribute-royalties (distributions (list 10 { song-id: uint, amount: uint })))
  (let (
    (results (map process-single-distribution distributions))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> (len distributions) u0) ERR_BATCH_PROCESSING_FAILED)
    (ok (len results))
  )
)

(define-public (withdraw-earnings)
  (let (
    (user-data (default-to { total-earned: u0, withdrawn: u0 } (map-get? user-earnings { user: tx-sender })))
    (available (- (get total-earned user-data) (get withdrawn user-data)))
  )
    (asserts! (> available u0) ERR_INSUFFICIENT_BALANCE)
    
    (try! (stx-transfer? available (as-contract tx-sender) tx-sender))
    (map-set user-earnings
      { user: tx-sender }
      (merge user-data { withdrawn: (+ (get withdrawn user-data) available) })
    )
    (ok available)
  )
)

(define-public (deactivate-song (song-id uint))
  (let (
    (song (unwrap! (map-get? songs { song-id: song-id }) ERR_SONG_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    (map-set songs
      { song-id: song-id }
      (merge song { is-active: false })
    )
    (ok true)
  )
)

(define-public (update-participant-split (song-id uint) (participant principal) (new-percentage uint) (new-role (string-ascii 50)))
  (let (
    (song (unwrap! (map-get? songs { song-id: song-id }) ERR_SONG_NOT_FOUND))
    (split (unwrap! (map-get? royalty-splits { song-id: song-id, participant: participant }) ERR_PARTICIPANT_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-percentage TOTAL_PERCENTAGE) ERR_INVALID_PERCENTAGE)
    
    (map-set royalty-splits
      { song-id: song-id, participant: participant }
      (merge split { percentage: new-percentage, role: new-role })
    )
    (ok true)
  )
)

(define-public (transfer-song-ownership (song-id uint) (new-owner principal))
  (let (
    (song (unwrap! (map-get? songs { song-id: song-id }) ERR_SONG_NOT_FOUND))
    (current-owner (get creator song))
    (transfer-count-data (default-to { count: u0 } (map-get? song-transfer-count { song-id: song-id })))
    (next-transfer-id (+ (get count transfer-count-data) u1))
  )
    (asserts! (or (is-eq tx-sender current-owner) (is-eq tx-sender CONTRACT_OWNER)) ERR_NOT_AUTHORIZED)
    (asserts! (not (is-eq current-owner new-owner)) ERR_TRANSFER_TO_SELF)
    (asserts! (not (is-eq new-owner CONTRACT_OWNER)) ERR_INVALID_NEW_OWNER)
    
    (map-set songs
      { song-id: song-id }
      (merge song { creator: new-owner })
    )
    
    (map-set song-ownership-history
      { song-id: song-id, transfer-id: next-transfer-id }
      {
        previous-owner: current-owner,
        new-owner: new-owner,
        transfer-timestamp: stacks-block-height
      }
    )
    
    (map-set song-transfer-count
      { song-id: song-id }
      { count: next-transfer-id }
    )
    
    (ok true)
  )
)

(define-read-only (get-song (song-id uint))
  (map-get? songs { song-id: song-id })
)

(define-read-only (get-participant-split (song-id uint) (participant principal))
  (map-get? royalty-splits { song-id: song-id, participant: participant })
)

(define-read-only (get-song-participants (song-id uint))
  (map-get? song-participants { song-id: song-id })
)

(define-read-only (get-user-earnings (user principal))
  (map-get? user-earnings { user: user })
)

(define-read-only (get-available-earnings (user principal))
  (let (
    (user-data (default-to { total-earned: u0, withdrawn: u0 } (map-get? user-earnings { user: user })))
  )
    (- (get total-earned user-data) (get withdrawn user-data))
  )
)

(define-read-only (get-total-songs)
  (var-get song-counter)
)

(define-read-only (get-contract-stats)
  {
    total-songs: (var-get song-counter),
    total-earnings: (var-get total-earnings),
    contract-owner: CONTRACT_OWNER
  }
)

(define-read-only (get-song-transfer-history (song-id uint) (transfer-id uint))
  (map-get? song-ownership-history { song-id: song-id, transfer-id: transfer-id })
)

(define-read-only (get-song-transfer-count (song-id uint))
  (default-to { count: u0 } (map-get? song-transfer-count { song-id: song-id }))
)

(define-read-only (get-song-owner (song-id uint))
  (match (map-get? songs { song-id: song-id })
    song-data (some (get creator song-data))
    none
  )
)

(define-private (get-percentage (participant { participant: principal, percentage: uint, role: (string-ascii 50) }))
  (get percentage participant)
)

(define-private (get-participant-address (participant { participant: principal, percentage: uint, role: (string-ascii 50) }))
  (get participant participant)
)

(define-private (set-participant-split (song-id uint) (participant { participant: principal, percentage: uint, role: (string-ascii 50) }))
  (begin
    (map-set royalty-splits
      { song-id: song-id, participant: (get participant participant) }
      {
        percentage: (get percentage participant),
        role: (get role participant),
        earned: u0
      }
    )
    (map-set user-earnings
      { user: (get participant participant) }
      (default-to { total-earned: u0, withdrawn: u0 } (map-get? user-earnings { user: (get participant participant) }))
    )
    true
  )
)

(define-private (update-participant-earnings (song-id uint) (participant principal) (total-amount uint))
  (let (
    (split (default-to { percentage: u0, role: "", earned: u0 } (map-get? royalty-splits { song-id: song-id, participant: participant })))
    (participant-amount (/ (* total-amount (get percentage split)) TOTAL_PERCENTAGE))
    (user-data (default-to { total-earned: u0, withdrawn: u0 } (map-get? user-earnings { user: participant })))
  )
    (map-set royalty-splits
      { song-id: song-id, participant: participant }
      (merge split { earned: (+ (get earned split) participant-amount) })
    )
    (map-set user-earnings
      { user: participant }
      (merge user-data { total-earned: (+ (get total-earned user-data) participant-amount) })
    )
    participant-amount
  )
)

(define-private (set-participant-for-song (participant { participant: principal, percentage: uint, role: (string-ascii 50) }) (acc { song-id: uint, success: bool }))
  (begin
    (set-participant-split (get song-id acc) participant)
    acc
  )
)

(define-private (update-participant-earnings-fold (participant principal) (acc { song-id: uint, total-amount: uint, success: bool }))
  (begin
    (update-participant-earnings (get song-id acc) participant (get total-amount acc))
    acc
  )
)

(define-private (process-single-distribution (distribution { song-id: uint, amount: uint }))
  (let (
    (song-id (get song-id distribution))
    (amount (get amount distribution))
    (song (unwrap-panic (map-get? songs { song-id: song-id })))
    (participants (default-to (list) (get participants (map-get? song-participants { song-id: song-id }))))
  )
    (if (and (get is-active song) (> amount u0))
      (begin
        (fold update-participant-earnings-fold participants { song-id: song-id, total-amount: amount, success: true })
        (map-set songs
          { song-id: song-id }
          (merge song { total-earned: (+ (get total-earned song) amount) })
        )
        (var-set total-earnings (+ (var-get total-earnings) amount))
        true
      )
      false
    )
  )
)
