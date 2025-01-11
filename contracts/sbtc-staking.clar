;; Title: sBTC Staking-as-a-Service Contract
;;
;; Summary:
;; A staking contract that enables users to stake sBTC tokens and earn rewards.
;; Implements a flexible staking mechanism with time-locked deposits and
;; reward multipliers based on lock duration.
;;
;; Description:
;; - Minimum stake amount: 0.001 sBTC
;; - Base reward rate: 5% APR
;; - Minimum lock period: 1 month (2628 blocks)
;; - Additional rewards based on lock duration
;; - Supports staking, reward claims, and unstaking after lock period

;; Define the trait for sBTC token interface
(define-trait sbtc-token-trait
    (
        (transfer (uint principal principal) (response bool uint))
        (get-balance (principal) (response uint uint))
    )
)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-already-staked (err u101))
(define-constant err-no-stake-found (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-minimum-stake (err u104))
(define-constant err-lock-period (err u105))
(define-constant err-invalid-amount (err u106))
(define-constant err-invalid-contract (err u107))
(define-constant minimum-stake-amount u100000) ;; 0.001 sBTC (8 decimals)
(define-constant blocks-per-year u52560) ;; Approximate blocks per year

;; State Variables
(define-data-var total-staked uint u0)
(define-data-var total-rewards uint u0)
(define-data-var last-reward-block uint u0)
(define-data-var sbtc-token principal 'SP3DX3H4FEYZJZ586MFBS25ZW3HZDMEW92260R2PR.sbtc)
(define-data-var rewards-rate uint u500) ;; 5% annual base rate (scaled by 100)

;; Helper function to validate sbtc contract
(define-private (is-valid-sbtc-contract (contract principal))
    (is-eq contract (var-get sbtc-token))
)

;; Data Maps
(define-map staker-positions
    principal
    {
        amount: uint,
        start-block: uint,
        lock-period: uint,
        rewards-claimed: uint,
        last-claim-block: uint
    }
)

(define-map staking-stats
    principal
    {
        total-staked: uint,
        total-rewards-claimed: uint,
        stake-count: uint
    }
)

;; Read-only Functions
(define-read-only (get-staker-position (staker principal))
    (map-get? staker-positions staker)
)

(define-read-only (get-staking-stats (staker principal))
    (map-get? staking-stats staker)
)

(define-read-only (get-total-staked)
    (var-get total-staked)
)

(define-read-only (calculate-rewards (staker principal))
    (let (
        (position (unwrap! (get-staker-position staker) (err u0)))
        (current-block block-height)
        (blocks-staked (- current-block (get last-claim-block position)))
        (stake-amount (get amount position))
        (lock-bonus (/ (get lock-period position) u52560))
    )
    (if (> blocks-staked u0)
        (let (
            (base-reward (* (* stake-amount (var-get rewards-rate)) (/ blocks-staked blocks-per-year)))
            (bonus-reward (* base-reward lock-bonus))
        )
        (ok (+ base-reward bonus-reward)))
        (ok u0)
    ))
)

;; Public Functions

;; Defines staking functionality
(define-public (stake-tokens (sbtc-contract <sbtc-token-trait>) (amount uint) (lock-period uint))
    (let (
        (staker tx-sender)
        (current-position (get-staker-position staker))
    )
    ;; Add contract validation
    (asserts! (is-valid-sbtc-contract (contract-of sbtc-contract)) err-invalid-contract)
    (asserts! (> amount minimum-stake-amount) err-minimum-stake)
    (asserts! (is-none current-position) err-already-staked)
    (asserts! (>= lock-period u2628) err-lock-period) ;; Minimum 1 month lock (2628 blocks)
    
    ;; Transfer sBTC to contract
    (try! (contract-call? sbtc-contract transfer 
        amount 
        staker 
        (as-contract tx-sender)
    ))
    
    ;; Update staking data
    (map-set staker-positions
        staker
        {
            amount: amount,
            start-block: block-height,
            lock-period: lock-period,
            rewards-claimed: u0,
            last-claim-block: block-height
        }
    )
    
    ;; Update staking stats
    (let ((stats (default-to 
        {total-staked: u0, total-rewards-claimed: u0, stake-count: u0}
        (get-staking-stats staker))))
        (map-set staking-stats
            staker
            {
                total-staked: (+ (get total-staked stats) amount),
                total-rewards-claimed: (get total-rewards-claimed stats),
                stake-count: (+ (get stake-count stats) u1)
            }
        )
    )
    
    ;; Update total staked
    (var-set total-staked (+ (var-get total-staked) amount))
    (ok true))
)

;; Defines reward claiming functionality
(define-public (claim-rewards (sbtc-contract <sbtc-token-trait>))
    (let (
        (staker tx-sender)
        (position (unwrap! (get-staker-position staker) err-no-stake-found))
        (rewards (unwrap! (calculate-rewards staker) (err u0)))
    )
    ;; Add contract validation
    (asserts! (is-valid-sbtc-contract (contract-of sbtc-contract)) err-invalid-contract)
    (asserts! (> rewards u0) (err u0))
    
    ;; Transfer rewards
    (try! (as-contract (contract-call? sbtc-contract transfer
        rewards
        (as-contract tx-sender)
        staker
    )))
    
    ;; Update stake info
    (map-set staker-positions
        staker
        {
            amount: (get amount position),
            start-block: (get start-block position),
            lock-period: (get lock-period position),
            rewards-claimed: (+ (get rewards-claimed position) rewards),
            last-claim-block: block-height
        }
    )
    
    ;; Update staking stats
    (let ((stats (unwrap! (get-staking-stats staker) err-no-stake-found)))
        (map-set staking-stats
            staker
            {
                total-staked: (get total-staked stats),
                total-rewards-claimed: (+ (get total-rewards-claimed stats) rewards),
                stake-count: (get stake-count stats)
            }
        )
    )
    
    (var-set total-rewards (+ (var-get total-rewards) rewards))
    (ok rewards))
)

;; Defines unstaking functionality
(define-public (unstake (sbtc-contract <sbtc-token-trait>))
    (let (
        (staker tx-sender)
        (position (unwrap! (get-staker-position staker) err-no-stake-found))
        (current-block block-height)
    )
    ;; Add contract validation
    (asserts! (is-valid-sbtc-contract (contract-of sbtc-contract)) err-invalid-contract)
    ;; Check lock period
    (asserts! (>= current-block (+ (get start-block position) (get lock-period position))) err-lock-period)
    
    ;; Claim any remaining rewards first
    (try! (claim-rewards sbtc-contract))
    
    ;; Return staked sBTC
    (try! (as-contract (contract-call? sbtc-contract transfer
        (get amount position)
        (as-contract tx-sender)
        staker
    )))
    
    ;; Clear stake data
    (map-delete staker-positions staker)
    
    ;; Update total staked
    (var-set total-staked (- (var-get total-staked) (get amount position)))
    (ok true))
)

;; Admin Functions
(define-public (update-rewards-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (< new-rate u10000) err-invalid-amount) ;; Max 100% APR
        (ok (var-set rewards-rate new-rate)))
)

(define-public (update-sbtc-token (new-token principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        ;; Add basic validation that the new token implements the required trait
        (asserts! (is-valid-sbtc-contract new-token) err-invalid-contract)
        (ok (var-set sbtc-token new-token)))
)