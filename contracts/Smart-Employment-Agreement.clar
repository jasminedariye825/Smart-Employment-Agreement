
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_AGREEMENT_NOT_FOUND (err u101))
(define-constant ERR_AGREEMENT_ALREADY_EXISTS (err u102))
(define-constant ERR_MILESTONE_NOT_FOUND (err u103))
(define-constant ERR_MILESTONE_ALREADY_COMPLETED (err u104))
(define-constant ERR_INSUFFICIENT_FUNDS (err u105))
(define-constant ERR_AGREEMENT_TERMINATED (err u106))
(define-constant ERR_INVALID_STATUS (err u107))
(define-constant ERR_PAYMENT_FAILED (err u108))
(define-constant ERR_BREACH_ALREADY_REPORTED (err u109))
(define-constant ERR_INVALID_PENALTY (err u110))
(define-constant ERR_VESTING_NOT_FOUND (err u111))
(define-constant ERR_CLIFF_NOT_REACHED (err u112))
(define-constant ERR_NO_VESTED_AMOUNT (err u113))
(define-constant ERR_INVALID_VESTING_PARAMS (err u114))
(define-constant ERR_REVIEW_NOT_FOUND (err u115))
(define-constant ERR_INVALID_SCORE (err u116))
(define-constant ERR_REVIEW_ALREADY_EXISTS (err u117))

(define-constant STATUS_ACTIVE u1)
(define-constant STATUS_COMPLETED u2)
(define-constant STATUS_TERMINATED u3)
(define-constant STATUS_BREACHED u4)

(define-constant MILESTONE_PENDING u1)
(define-constant MILESTONE_COMPLETED u2)
(define-constant MILESTONE_DISPUTED u3)

(define-constant REVIEW_POOR u1)
(define-constant REVIEW_BELOW_AVERAGE u2)
(define-constant REVIEW_AVERAGE u3)
(define-constant REVIEW_ABOVE_AVERAGE u4)
(define-constant REVIEW_EXCELLENT u5)

(define-data-var next-agreement-id uint u1)
(define-data-var contract-owner principal tx-sender)

(define-map employment-agreements
  uint
  {
    employer: principal,
    employee: principal,
    base-salary: uint,
    bonus-pool: uint,
    penalty-rate: uint,
    start-block: uint,
    duration-blocks: uint,
    status: uint,
    total-paid: uint,
    penalty-pool: uint
  }
)

(define-map milestones
  { agreement-id: uint, milestone-id: uint }
  {
    description: (string-ascii 100),
    payment-amount: uint,
    due-block: uint,
    status: uint,
    completion-block: (optional uint)
  }
)

(define-map milestone-counter
  uint
  uint
)

(define-map breach-reports
  { agreement-id: uint, report-id: uint }
  {
    reporter: principal,
    description: (string-ascii 200),
    penalty-amount: uint,
    report-block: uint,
    resolved: bool
  }
)

(define-map breach-counter
  uint
  uint
)

(define-map vesting-schedules
  uint
  {
    agreement-id: uint,
    total-amount: uint,
    cliff-blocks: uint,
    vesting-blocks: uint,
    start-block: uint,
    withdrawn-amount: uint
  }
)

(define-data-var next-vesting-id uint u1)

(define-map performance-reviews
  { agreement-id: uint, review-id: uint }
  {
    reviewer: principal,
    score: uint,
    feedback: (string-ascii 300),
    review-block: uint,
    bonus-adjustment: uint
  }
)

(define-map review-counter
  uint
  uint
)

(define-public (create-agreement
  (employee principal)
  (base-salary uint)
  (bonus-pool uint)
  (penalty-rate uint)
  (duration-blocks uint)
)
  (let
    (
      (agreement-id (var-get next-agreement-id))
      (employer tx-sender)
      (start-block stacks-block-height)
    )
    (asserts! (> base-salary u0) ERR_INVALID_STATUS)
    (asserts! (> duration-blocks u0) ERR_INVALID_STATUS)
    (asserts! (<= penalty-rate u100) ERR_INVALID_PENALTY)
    
    (map-set employment-agreements agreement-id
      {
        employer: employer,
        employee: employee,
        base-salary: base-salary,
        bonus-pool: bonus-pool,
        penalty-rate: penalty-rate,
        start-block: start-block,
        duration-blocks: duration-blocks,
        status: STATUS_ACTIVE,
        total-paid: u0,
        penalty-pool: u0
      }
    )
    
    (map-set milestone-counter agreement-id u0)
    (map-set breach-counter agreement-id u0)
    (map-set review-counter agreement-id u0)
    (var-set next-agreement-id (+ agreement-id u1))
    
    (ok agreement-id)
  )
)

(define-public (add-milestone
  (agreement-id uint)
  (description (string-ascii 100))
  (payment-amount uint)
  (blocks-from-start uint)
)
  (let
    (
      (agreement (unwrap! (map-get? employment-agreements agreement-id) ERR_AGREEMENT_NOT_FOUND))
      (milestone-id (+ (default-to u0 (map-get? milestone-counter agreement-id)) u1))
      (due-block (+ (get start-block agreement) blocks-from-start))
    )
    (asserts! (or (is-eq tx-sender (get employer agreement)) (is-eq tx-sender (get employee agreement))) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status agreement) STATUS_ACTIVE) ERR_AGREEMENT_TERMINATED)
    (asserts! (> payment-amount u0) ERR_INVALID_STATUS)
    
    (map-set milestones
      { agreement-id: agreement-id, milestone-id: milestone-id }
      {
        description: description,
        payment-amount: payment-amount,
        due-block: due-block,
        status: MILESTONE_PENDING,
        completion-block: none
      }
    )
    
    (map-set milestone-counter agreement-id milestone-id)
    (ok milestone-id)
  )
)

(define-public (complete-milestone
  (agreement-id uint)
  (milestone-id uint)
)
  (let
    (
      (agreement (unwrap! (map-get? employment-agreements agreement-id) ERR_AGREEMENT_NOT_FOUND))
      (milestone (unwrap! (map-get? milestones { agreement-id: agreement-id, milestone-id: milestone-id }) ERR_MILESTONE_NOT_FOUND))
      (payment-amount (get payment-amount milestone))
    )
    (asserts! (is-eq tx-sender (get employer agreement)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status agreement) STATUS_ACTIVE) ERR_AGREEMENT_TERMINATED)
    (asserts! (is-eq (get status milestone) MILESTONE_PENDING) ERR_MILESTONE_ALREADY_COMPLETED)
    
    (map-set milestones
      { agreement-id: agreement-id, milestone-id: milestone-id }
      (merge milestone {
        status: MILESTONE_COMPLETED,
        completion-block: (some stacks-block-height)
      })
    )
    
    (try! (process-payment agreement-id payment-amount))
    (ok true)
  )
)

(define-public (report-breach
  (agreement-id uint)
  (description (string-ascii 200))
  (penalty-amount uint)
)
  (let
    (
      (agreement (unwrap! (map-get? employment-agreements agreement-id) ERR_AGREEMENT_NOT_FOUND))
      (report-id (+ (default-to u0 (map-get? breach-counter agreement-id)) u1))
    )
    (asserts! (or (is-eq tx-sender (get employer agreement)) (is-eq tx-sender (get employee agreement))) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status agreement) STATUS_ACTIVE) ERR_AGREEMENT_TERMINATED)
    
    (map-set breach-reports
      { agreement-id: agreement-id, report-id: report-id }
      {
        reporter: tx-sender,
        description: description,
        penalty-amount: penalty-amount,
        report-block: stacks-block-height,
        resolved: false
      }
    )
    
    (map-set breach-counter agreement-id report-id)
    (ok report-id)
  )
)

(define-public (resolve-breach
  (agreement-id uint)
  (report-id uint)
  (penalty-approved bool)
)
  (let
    (
      (agreement (unwrap! (map-get? employment-agreements agreement-id) ERR_AGREEMENT_NOT_FOUND))
      (breach-report (unwrap! (map-get? breach-reports { agreement-id: agreement-id, report-id: report-id }) ERR_MILESTONE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (not (get resolved breach-report)) ERR_BREACH_ALREADY_REPORTED)
    
    (map-set breach-reports
      { agreement-id: agreement-id, report-id: report-id }
      (merge breach-report { resolved: true })
    )
    
    (if penalty-approved
      (begin
        (map-set employment-agreements agreement-id
          (merge agreement {
            penalty-pool: (+ (get penalty-pool agreement) (get penalty-amount breach-report)),
            status: STATUS_BREACHED
          })
        )
        (ok true)
      )
      (ok false)
    )
  )
)

(define-public (pay-base-salary (agreement-id uint))
  (let
    (
      (agreement (unwrap! (map-get? employment-agreements agreement-id) ERR_AGREEMENT_NOT_FOUND))
      (salary-amount (get base-salary agreement))
    )
    (asserts! (is-eq tx-sender (get employer agreement)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status agreement) STATUS_ACTIVE) ERR_AGREEMENT_TERMINATED)
    
    (try! (process-payment agreement-id salary-amount))
    (ok salary-amount)
  )
)

(define-public (distribute-bonus
  (agreement-id uint)
  (bonus-amount uint)
)
  (let
    (
      (agreement (unwrap! (map-get? employment-agreements agreement-id) ERR_AGREEMENT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get employer agreement)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status agreement) STATUS_ACTIVE) ERR_AGREEMENT_TERMINATED)
    (asserts! (<= bonus-amount (get bonus-pool agreement)) ERR_INSUFFICIENT_FUNDS)
    
    (map-set employment-agreements agreement-id
      (merge agreement {
        bonus-pool: (- (get bonus-pool agreement) bonus-amount)
      })
    )
    
    (try! (process-payment agreement-id bonus-amount))
    (ok bonus-amount)
  )
)

(define-public (terminate-agreement (agreement-id uint))
  (let
    (
      (agreement (unwrap! (map-get? employment-agreements agreement-id) ERR_AGREEMENT_NOT_FOUND))
    )
    (asserts! (or (is-eq tx-sender (get employer agreement)) (is-eq tx-sender (get employee agreement))) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status agreement) STATUS_ACTIVE) ERR_AGREEMENT_TERMINATED)
    
    (map-set employment-agreements agreement-id
      (merge agreement { status: STATUS_TERMINATED })
    )
    
    (ok true)
  )
)

(define-private (process-payment (agreement-id uint) (amount uint))
  (let
    (
      (agreement (unwrap! (map-get? employment-agreements agreement-id) ERR_AGREEMENT_NOT_FOUND))
      (employee (get employee agreement))
    )
    (match (stx-transfer? amount tx-sender employee)
      success (begin
        (map-set employment-agreements agreement-id
          (merge agreement {
            total-paid: (+ (get total-paid agreement) amount)
          })
        )
        (ok true)
      )
      error ERR_PAYMENT_FAILED
    )
  )
)

(define-read-only (get-agreement (agreement-id uint))
  (map-get? employment-agreements agreement-id)
)

(define-read-only (get-milestone (agreement-id uint) (milestone-id uint))
  (map-get? milestones { agreement-id: agreement-id, milestone-id: milestone-id })
)

(define-read-only (get-breach-report (agreement-id uint) (report-id uint))
  (map-get? breach-reports { agreement-id: agreement-id, report-id: report-id })
)

(define-read-only (get-milestone-count (agreement-id uint))
  (default-to u0 (map-get? milestone-counter agreement-id))
)

(define-read-only (get-breach-count (agreement-id uint))
  (default-to u0 (map-get? breach-counter agreement-id))
)

(define-read-only (is-agreement-expired (agreement-id uint))
  (match (map-get? employment-agreements agreement-id)
    agreement (let
      (
        (end-block (+ (get start-block agreement) (get duration-blocks agreement)))
      )
      (>= stacks-block-height end-block)
    )
    false
  )
)

(define-read-only (calculate-penalty (agreement-id uint) (violation-severity uint))
  (match (map-get? employment-agreements agreement-id)
    agreement (let
      (
        (base-penalty (* (get base-salary agreement) (get penalty-rate agreement)))
        (severity-multiplier (if (<= violation-severity u5) violation-severity u5))
      )
      (/ (* base-penalty severity-multiplier) u100)
    )
    u0
  )
)

(define-read-only (get-total-compensation (agreement-id uint))
  (match (map-get? employment-agreements agreement-id)
    agreement (+ (get total-paid agreement) (get bonus-pool agreement))
    u0
  )
)

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-public (create-vesting-schedule
  (agreement-id uint)
  (total-amount uint)
  (cliff-blocks uint)
  (vesting-blocks uint)
)
  (let
    (
      (agreement (unwrap! (map-get? employment-agreements agreement-id) ERR_AGREEMENT_NOT_FOUND))
      (vesting-id (var-get next-vesting-id))
      (start-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender (get employer agreement)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status agreement) STATUS_ACTIVE) ERR_AGREEMENT_TERMINATED)
    (asserts! (> total-amount u0) ERR_INVALID_VESTING_PARAMS)
    (asserts! (> vesting-blocks u0) ERR_INVALID_VESTING_PARAMS)
    (asserts! (< cliff-blocks vesting-blocks) ERR_INVALID_VESTING_PARAMS)
    
    (map-set vesting-schedules vesting-id
      {
        agreement-id: agreement-id,
        total-amount: total-amount,
        cliff-blocks: cliff-blocks,
        vesting-blocks: vesting-blocks,
        start-block: start-block,
        withdrawn-amount: u0
      }
    )
    
    (var-set next-vesting-id (+ vesting-id u1))
    (ok vesting-id)
  )
)

(define-public (withdraw-vested-amount (vesting-id uint))
  (let
    (
      (vesting (unwrap! (map-get? vesting-schedules vesting-id) ERR_VESTING_NOT_FOUND))
      (agreement-id (get agreement-id vesting))
      (agreement (unwrap! (map-get? employment-agreements agreement-id) ERR_AGREEMENT_NOT_FOUND))
      (vested-amount (unwrap! (calculate-vested-amount vesting-id) ERR_NO_VESTED_AMOUNT))
      (withdrawable (- vested-amount (get withdrawn-amount vesting)))
    )
    (asserts! (is-eq tx-sender (get employee agreement)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status agreement) STATUS_ACTIVE) ERR_AGREEMENT_TERMINATED)
    (asserts! (> withdrawable u0) ERR_NO_VESTED_AMOUNT)
    
    (map-set vesting-schedules vesting-id
      (merge vesting {
        withdrawn-amount: (+ (get withdrawn-amount vesting) withdrawable)
      })
    )
    
    (try! (stx-transfer? withdrawable (get employer agreement) (get employee agreement)))
    (ok withdrawable)
  )
)

(define-read-only (calculate-vested-amount (vesting-id uint))
  (match (map-get? vesting-schedules vesting-id)
    vesting (let
      (
        (current-block stacks-block-height)
        (start-block (get start-block vesting))
        (cliff-end (+ start-block (get cliff-blocks vesting)))
        (vesting-end (+ start-block (get vesting-blocks vesting)))
        (total-amount (get total-amount vesting))
      )
      (if (< current-block cliff-end)
        (ok u0)
        (if (>= current-block vesting-end)
          (ok total-amount)
          (let
            (
              (elapsed-blocks (- current-block start-block))
              (total-vesting-blocks (get vesting-blocks vesting))
              (vested (/ (* total-amount elapsed-blocks) total-vesting-blocks))
            )
            (ok vested)
          )
        )
      )
    )
    ERR_VESTING_NOT_FOUND
  )
)

(define-read-only (get-vesting-schedule (vesting-id uint))
  (map-get? vesting-schedules vesting-id)
)

(define-read-only (get-withdrawable-amount (vesting-id uint))
  (let
    (
      (vesting (unwrap! (map-get? vesting-schedules vesting-id) ERR_VESTING_NOT_FOUND))
      (vested-amount (unwrap! (calculate-vested-amount vesting-id) ERR_NO_VESTED_AMOUNT))
      (withdrawable (- vested-amount (get withdrawn-amount vesting)))
    )
    (ok withdrawable)
  )
)

(define-public (submit-performance-review
  (agreement-id uint)
  (score uint)
  (feedback (string-ascii 300))
)
  (let
    (
      (agreement (unwrap! (map-get? employment-agreements agreement-id) ERR_AGREEMENT_NOT_FOUND))
      (review-id (+ (default-to u0 (map-get? review-counter agreement-id)) u1))
      (bonus-adjustment (calculate-bonus-adjustment (get base-salary agreement) score))
    )
    (asserts! (is-eq tx-sender (get employer agreement)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status agreement) STATUS_ACTIVE) ERR_AGREEMENT_TERMINATED)
    (asserts! (and (>= score u1) (<= score u5)) ERR_INVALID_SCORE)
    
    (map-set performance-reviews
      { agreement-id: agreement-id, review-id: review-id }
      {
        reviewer: tx-sender,
        score: score,
        feedback: feedback,
        review-block: stacks-block-height,
        bonus-adjustment: bonus-adjustment
      }
    )
    
    (map-set employment-agreements agreement-id
      (merge agreement {
        bonus-pool: (+ (get bonus-pool agreement) bonus-adjustment)
      })
    )
    
    (map-set review-counter agreement-id review-id)
    (ok review-id)
  )
)

(define-read-only (calculate-bonus-adjustment (base-salary uint) (score uint))
  (let
    (
      (multiplier (if (is-eq score REVIEW_POOR)
                    u0
                    (if (is-eq score REVIEW_BELOW_AVERAGE)
                      u5
                      (if (is-eq score REVIEW_AVERAGE)
                        u10
                        (if (is-eq score REVIEW_ABOVE_AVERAGE)
                          u20
                          u30)))))
    )
    (/ (* base-salary multiplier) u100)
  )
)

(define-read-only (get-performance-review (agreement-id uint) (review-id uint))
  (map-get? performance-reviews { agreement-id: agreement-id, review-id: review-id })
)

(define-read-only (get-review-count (agreement-id uint))
  (default-to u0 (map-get? review-counter agreement-id))
)

(define-read-only (get-latest-performance-score (agreement-id uint))
  (let
    (
      (total-reviews (get-review-count agreement-id))
    )
    (if (is-eq total-reviews u0)
      (ok u0)
      (match (get-performance-review agreement-id total-reviews)
        review (ok (get score review))
        (ok u0)
      )
    )
  )
)
