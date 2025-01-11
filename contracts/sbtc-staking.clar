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