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

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-already-staked (err u101))
(define-constant err-no-stake-found (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-minimum-stake (err u104))
(define-constant err-lock-period (err u105))
(define-constant err-invalid-amount (err u106))
(define-constant minimum-stake-amount u100000) ;; 0.001 sBTC (8 decimals)
(define-constant rewards-rate u500) ;; 5% annual base rate (scaled by 100)
(define-constant blocks-per-year u52560) ;; Approximate blocks per year

;; State Variables
(define-data-var total-staked uint u0)
(define-data-var total-rewards uint u0)
(define-data-var last-reward-block uint u0)

;; Data Maps
;; Stores individual stake information per user
(define-map stakes
    principal
    {
        amount: uint,
        start-block: uint,
        lock-period: uint,
        rewards-claimed: uint,
        last-claim-block: uint
    }
)

;; Tracks historical staking metrics per user
(define-map staking-stats
    principal
    {
        total-staked: uint,
        total-rewards-claimed: uint,
        stake-count: uint
    }
)

;; Read-only Functions

;; Returns stake information for a given staker
(define-read-only (get-stake (staker principal))
    (map-get? stakes staker)
)

;; Returns historical staking statistics for a given staker
(define-read-only (get-staking-stats (staker principal))
    (map-get? staking-stats staker)
)

;; Returns total amount of sBTC currently staked
(define-read-only (get-total-staked)
    (var-get total-staked)
)

;; Calculates pending rewards for a staker
(define-read-only (calculate-rewards (staker principal))
    (let (
        (stake (unwrap! (get-stake staker) (err u0)))
        (current-block block-height)
        (blocks-staked (- current-block (get last-claim-block stake)))
        (stake-amount (get amount stake))
        (lock-bonus (/ (get lock-period stake) u52560))
    )
    (if (> blocks-staked u0)
        (let (
            (base-reward (* (* stake-amount rewards-rate) (/ blocks-staked blocks-per-year)))
            (bonus-reward (* base-reward lock-bonus))
        )
        (+ base-reward bonus-reward))
        u0
    ))
)

;; Public Functions

;; Stakes sBTC tokens with specified lock period
(define-public (stake (amount uint) (lock-period uint))
    (let (
        (staker tx-sender)
        (current-stake (get-stake staker))
    )
    (asserts! (> amount minimum-stake-amount) err-minimum-stake)
    (asserts! (is-none current-stake) err-already-staked)
    (asserts! (>= lock-period u2628) err-lock-period)
    
    (try! (contract-call? 'SP3DX3H4FEYZJZ586MFBS25ZW3HZDMEW92260R2PR.sbtc transfer 
        amount 
        staker 
        (as-contract tx-sender)
    ))
    
    (map-set stakes
        staker
        {
            amount: amount,
            start-block: block-height,
            lock-period: lock-period,
            rewards-claimed: u0,
            last-claim-block: block-height
        }
    )
    
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
    
    (var-set total-staked (+ (var-get total-staked) amount))
    (ok true))
)

;; Claims accumulated staking rewards
(define-public (claim-rewards)
    (let (
        (staker tx-sender)
        (stake (unwrap! (get-stake staker) err-no-stake-found))
        (rewards (calculate-rewards staker))
    )
    (asserts! (> rewards u0) (err u0))
    
    (try! (as-contract (contract-call? 'SP3DX3H4FEYZJZ586MFBS25ZW3HZDMEW92260R2PR.sbtc transfer
        rewards
        (as-contract tx-sender)
        staker
    )))
    
    (map-set stakes
        staker
        {
            amount: (get amount stake),
            start-block: (get start-block stake),
            lock-period: (get lock-period stake),
            rewards-claimed: (+ (get rewards-claimed stake) rewards),
            last-claim-block: block-height
        }
    )
    
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

;; Unstakes tokens after lock period expires
(define-public (unstake)
    (let (
        (staker tx-sender)
        (stake (unwrap! (get-stake staker) err-no-stake-found))
        (current-block block-height)
    )
    (asserts! (>= current-block (+ (get start-block stake) (get lock-period stake))) err-lock-period)
    
    (try! (claim-rewards))
    
    (try! (as-contract (contract-call? 'SP3DX3H4FEYZJZ586MFBS25ZW3HZDMEW92260R2PR.sbtc transfer
        (get amount stake)
        (as-contract tx-sender)
        staker
    )))
    
    (map-delete stakes staker)
    
    (var-set total-staked (- (var-get total-staked) (get amount stake)))
    (ok true))
)

;; Admin Functions

;; Updates the base reward rate (owner only)
(define-public (update-rewards-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (< new-rate u10000) err-invalid-amount)
        (ok (var-set rewards-rate new-rate)))
)