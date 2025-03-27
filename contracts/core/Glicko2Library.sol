// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Constants for Glicko-2 algorithm
int256 constant RATING_SCALE_FACTOR = 173_7177; // Scaling factor for ratings (multiply by 1000 for precision)
int256 constant INITIAL_RATING = 1500000; // Initial rating for new players (1500 * 1000 for precision)
int256 constant MAX_GLICKO2_RATING = 3000000; // Maximum rating for Glicko-2 (3000 * 1000 for precision)
int256 constant MIN_GLICKO2_RATING = 100000; // Minimum rating for Glicko-2 (100 * 1000 for precision)
int256 constant INITIAL_DEVIATION = 350000; // Initial rating deviation (350 * 1000 for precision)
int256 constant INITIAL_VOLATILITY = 60000; // Initial volatility (0.06 * 1000000 for precision)
int256 constant MIN_RATING_DEVIATION = 30000; // Minimum rating deviation (30 * 1000 for precision)
int256 constant MAX_RATING_DEVIATION = 350000; // Maximum rating deviation (350 * 1000 for precision)
int256 constant MIN_PHI_GLICKO2 = (MIN_RATING_DEVIATION * 1000000) /
    RATING_SCALE_FACTOR; // Minimum RD in Glicko-2 scale
int256 constant MAX_PHI_GLICKO2 = (MAX_RATING_DEVIATION * 1000000) /
    RATING_SCALE_FACTOR; // Maximum RD in Glicko-2 scale

// Result constants
uint8 constant VICTORY = 1;
uint8 constant DEFEAT = 0;

// Player rating data
struct PlayerRatingData {
    int256 ratingScore; // Player's rating (1500000 = 1500 rating points)
    int256 ratingDeviation; // Rating deviation (350000 = 350 RD points)
    int256 ratingVolatility; // Rating volatility (60000 = 0.06 volatility)
    uint32 lastUpdateTimestamp; // Timestamp of last rating update
}

// Parameters for rating calculation
struct RatingCalculationParams {
    int256 rating;
    int256 ratingDeviation;
    int256 volatility;
    int256 opponentRating;
    int256 opponentRatingDeviation;
    uint8 outcome;
}

struct RatingUpdateResult {
    int256 newRating;
    int256 newDeviation;
    int256 newVolatility;
    int256 ratingChange;
}

struct Glicko2Scale {
    int256 mu;
    int256 phi;
    int256 opponentMu;
    int256 opponentPhi;
}

struct IntermediateValues {
    int256 v;
    int256 g;
    int256 e;
    int256 newVolatility;
}

struct NewRatingCalcParams {
    int256 phiStar;
    int256 phiStarSquared;
    int256 newPhi;
    int256 scaledPhi;
    int256 scaledG;
    int256 difference;
    int256 newMu;
}

struct RatingCalcInputs {
    int256 v;
    int256 g;
    int256 e;
    int256 newVolatility;
    uint8 outcome;
}

/** ERRORS */
error PlayerNotInitialized();

/**
 * @title Glicko2Library
 * @dev Implementation of the Glicko-2 rating system for 1v1 games
 * Based on Mark Glickman's Glicko-2 system: http://www.glicko.net/glicko/glicko2.pdf
 */
library Glicko2Library {
    /**
     * @dev Record a game result against a player with known stats
     * @param playerOneData Stats of the player
     * @param playerTwoData Stats of the opponent player
     * @param outcome Outcome of the game (VICTORY or DEFEAT)
     */
    function calculateResultsUsingStats(
        PlayerRatingData memory playerOneData,
        PlayerRatingData memory playerTwoData,
        uint8 outcome
    ) internal view returns (RatingUpdateResult memory) {
        // Check
        if (playerOneData.ratingScore == 0) {
            revert PlayerNotInitialized();
        }
        // Adjust player one's rating deviation for inactivity if necessary
        playerOneData
            .ratingDeviation = calculateInactivityAdjustedRatingDeviation(
            playerOneData.ratingDeviation,
            playerOneData.ratingVolatility,
            playerOneData.lastUpdateTimestamp
        );
        // Submit player one's data and player two's data to the rating calculation and get the result
        RatingUpdateResult memory playerOneResult = calculatePlayerRating(
            playerOneData,
            playerTwoData,
            outcome
        );
        return playerOneResult;
    }

    /**
     * @dev Calculate new rating for a single player
     */
    function calculatePlayerRating(
        PlayerRatingData memory playerData,
        PlayerRatingData memory opponentData,
        uint8 outcome
    ) internal pure returns (RatingUpdateResult memory) {
        RatingCalculationParams memory params = RatingCalculationParams({
            rating: playerData.ratingScore,
            ratingDeviation: playerData.ratingDeviation,
            volatility: playerData.ratingVolatility,
            opponentRating: opponentData.ratingScore,
            opponentRatingDeviation: opponentData.ratingDeviation,
            outcome: outcome
        });
        (
            int256 newRating,
            int256 newDeviation,
            int256 newVolatility
        ) = calculateUpdatedRating(params);
        // Glicko-2's formulas in their pure form might calculate a tiny negative adjustment or zero adjustment for extreme mismatches
        // Ensure winners always gain at least 1 point
        if (outcome == 1 && newRating <= playerData.ratingScore) {
            newRating = playerData.ratingScore + 1000; // +1 point minimum (scaled)
        }
        // Ensure losers always lose at least 1 point
        if (outcome == 0 && newRating >= playerData.ratingScore) {
            newRating = playerData.ratingScore - 1000; // -1 point minimum (scaled)
        }
        return
            RatingUpdateResult({
                newRating: newRating,
                newDeviation: newDeviation,
                newVolatility: newVolatility,
                ratingChange: newRating - playerData.ratingScore
            });
    }

    /**
     * @dev Calculate the rating deviation for a player taking into account inactivity
     * @param currentRatingDeviation Current rating deviation
     * @param currentRatingVolatility Current rating volatility
     * @param lastUpdateTimestamp Last update timestamp
     * @return Adjusted rating deviation
     */
    function calculateInactivityAdjustedRatingDeviation(
        int256 currentRatingDeviation,
        int256 currentRatingVolatility,
        uint32 lastUpdateTimestamp
    ) internal view returns (int256) {
        // Calculate the time difference in weeks (simplified)
        uint256 inactiveWeeks = (block.timestamp - lastUpdateTimestamp) /
            1 weeks;
        // If player has been inactive more than 1 week, increase the rating deviation
        if (inactiveWeeks > 0) {
            // Cap at 52 weeks
            if (inactiveWeeks > 52) {
                inactiveWeeks = 52;
            }
            // Convert to Glicko-2 scale
            int256 deviationScale = (currentRatingDeviation * 10000000) /
                RATING_SCALE_FACTOR;
            // Calculate new rating deviation based on inactivity
            for (uint256 i = 0; i < inactiveWeeks; i++) {
                deviationScale = sqrt(
                    (deviationScale * deviationScale) +
                        (currentRatingVolatility * currentRatingVolatility)
                );
            }

            // Convert back to Glicko scale and ensure it doesn't exceed the maximum
            int256 newDeviation = (deviationScale * RATING_SCALE_FACTOR) /
                10000000;
            if (newDeviation > MAX_RATING_DEVIATION) {
                newDeviation = MAX_RATING_DEVIATION;
            }
            if (newDeviation < MIN_RATING_DEVIATION) {
                newDeviation = MIN_RATING_DEVIATION;
            }

            currentRatingDeviation = newDeviation;
        }

        return currentRatingDeviation;
    }

    /**
     * @dev Convert ratings to Glicko-2 scale
     */
    function convertToGlicko2Scale(
        RatingCalculationParams memory params
    ) internal pure returns (Glicko2Scale memory) {
        // Convert RD to phi (φ = RD / 173.7177)
        // For RD = 350000 (350 * 1000), we want phi ≈ 2015000
        int256 phi = (params.ratingDeviation * 10000000) / RATING_SCALE_FACTOR;

        // Convert rating to mu (μ = (R - 1500) / 173.7177)
        // For rating = 1500000 (1500 * 1000), we want mu = 0
        int256 mu = ((params.rating - INITIAL_RATING) * 10000000) /
            RATING_SCALE_FACTOR;

        int256 opponentMu = ((params.opponentRating - INITIAL_RATING) *
            10000000) / RATING_SCALE_FACTOR;

        int256 opponentPhi = (params.opponentRatingDeviation * 10000000) /
            RATING_SCALE_FACTOR;

        return
            Glicko2Scale({
                mu: mu,
                phi: phi,
                opponentMu: opponentMu,
                opponentPhi: opponentPhi
            });
    }

    /**
     * @dev Calculate intermediate values for rating update
     */
    function calculateIntermediateValues(
        Glicko2Scale memory scale
    ) internal pure returns (int256, int256, int256) {
        int256 g = calculateG(scale.opponentPhi);
        int256 e = calculateE(scale.mu, scale.opponentMu, g);
        int256 v = calculateV(g, e);
        return (v, g, e);
    }

    /**
     * @dev Update rating deviation and calculate new rating
     */
    function calculateNewRating(
        Glicko2Scale memory scale,
        RatingCalcInputs memory inputs
    ) internal pure returns (int256, int256) {
        NewRatingCalcParams memory calc;
        // Step 1: Calculate phi-star (φ*) based on phi and volatility
        calc.phiStar = sqrt(
            (scale.phi * scale.phi) +
                (inputs.newVolatility * inputs.newVolatility)
        );
        // Step 2: Calculate new phi (φ') using phi-star and variance (v)
        calc.phiStarSquared = (calc.phiStar * calc.phiStar);
        calc.phiStarSquared = calc.phiStarSquared / 1000000;
        int256 denominator = ((1000000 * 1000000) / calc.phiStarSquared) +
            ((1000000 * 1000000) / inputs.v);
        // Calculate the new phi aka newRD == φ' = 1 / √(1/φ*² + 1/v)
        calc.newPhi = (1000000000) / sqrt(denominator);
        // Ensure phi stays within bounds : optional
        // if (calc.newPhi < MIN_PHI_GLICKO2) {
        //     calc.newPhi = MIN_PHI_GLICKO2;
        // } else if (calc.newPhi > MAX_PHI_GLICKO2) {
        //     calc.newPhi = MAX_PHI_GLICKO2;
        // }

        // Step 3: Calculate new mu (μ') using mu, phi', g, and outcome difference
        int256 outcomeValue = inputs.outcome == VICTORY
            ? int256(1000000)
            : int256(0);
        calc.difference = outcomeValue - inputs.e;
        // Formula: mu' = mu + phi'^2 * g * (outcome - E)
        calc.newMu =
            scale.mu +
            ((calc.newPhi * calc.newPhi) * inputs.g * calc.difference) /
            (1000000 * 1000000 * 1000000);
        // Step 4: Convert back to original Glicko scale
        int256 newRating = INITIAL_RATING +
            ((calc.newMu * RATING_SCALE_FACTOR) / 10000000);
        // Ensure new rating stays within bounds : optional
        // if (newRating > MAX_GLICKO2_RATING) {
        //     newRating = MAX_GLICKO2_RATING;
        // } else if (newRating < MIN_GLICKO2_RATING) {
        //     newRating = MIN_GLICKO2_RATING;
        // }

        int256 newRD = (calc.newPhi * RATING_SCALE_FACTOR) / 10_000_000;
        return (newRating, newRD);
    }

    /**
     * @dev Calculate intermediate values including volatility
     */
    function calculateIntermediateWithVolatility(
        Glicko2Scale memory scale,
        int256 volatility,
        uint8 outcome
    ) internal pure returns (IntermediateValues memory) {
        (int256 v, int256 g, int256 e) = calculateIntermediateValues(scale);

        int256 outcomeValue = outcome == VICTORY ? int256(1000000) : int256(0);
        int256 delta = calculateDelta(v, g, outcomeValue, e);
        int256 newVolatility = calculateNewVolatility(
            volatility,
            delta,
            scale.phi,
            v,
            e
        );

        return IntermediateValues(v, g, e, newVolatility);
    }

    /**
     * @dev Calculate new rating based on game outcome
     */
    function calculateUpdatedRating(
        RatingCalculationParams memory params
    ) internal pure returns (int256, int256, int256) {
        Glicko2Scale memory scale = convertToGlicko2Scale(params);
        IntermediateValues memory values = calculateIntermediateWithVolatility(
            scale,
            params.volatility,
            params.outcome
        );

        RatingCalcInputs memory inputs = RatingCalcInputs({
            v: values.v,
            g: values.g,
            e: values.e,
            newVolatility: values.newVolatility,
            outcome: params.outcome
        });

        (int256 newRating, int256 newRd) = calculateNewRating(scale, inputs);
        return (newRating, newRd, values.newVolatility);
    }

    /**
     * @dev Calculate the g function of the Glicko-2 system : g(φ) = 1/sqrt(1 + 3φ²/π²)
     * @param phi Rating deviation in Glicko-2 scale
     * @return g value
     */
    function calculateG(int256 phi) internal pure returns (int256) {
        // Constants for precision
        int256 pi = 3141593; // π * 1000000

        // phi comes in scaled by 1000000
        // First calculate phi^2/pi^2 maintaining precision
        int256 phiSquared = (phi * phi) / 1000000; // First divide to avoid overflow

        int256 piSquared = (pi * pi) / 1000000;

        int256 phiOverPiSquared = (phiSquared * 1000000) / piSquared;

        // Now calculate 3 * phi^2/pi^2
        int256 term = 3 * phiOverPiSquared;

        // Add 1 (scaled) to the term
        int256 sum = 1000000 + term;

        // Scale up before sqrt to maintain precision through the sqrt operation
        int256 scaledForSqrt = sum * 1000000;

        // Take sqrt and maintain scale
        int256 sqrtValue = sqrt(scaledForSqrt);

        // Calculate final g value: 1/sqrt(1 + 3phi^2/pi^2)
        int256 result = (1000000 * 1000000) / sqrtValue;

        return result;
    }

    /**
     * @dev Calculate the E function (expected outcome) of the Glicko-2 system
     * @param mu Player's rating in Glicko-2 scale
     * @param opponentMu Opponent's rating in Glicko-2 scale
     * @param g g(phi) value
     * @return Expected outcome
     */
    function calculateE(
        int256 mu,
        int256 opponentMu,
        int256 g
    ) internal pure returns (int256) {
        // 1 / (1 + e^(-g * (mu - opponentMu)))

        int256 exponent = (-g * (mu - opponentMu)) / 1000000; // Divide by 1000000 to account for scaling

        int256 expValue = exp(exponent);

        // Scale up before division to maintain precision
        int256 result = (1000000 * 1000000) / (1000000 + expValue);

        return result;
    }

    /**
     * @dev Calculate the variance of a player's rating based on game outcomes
     * Following original Glicko-2: v = 1/(g²*e*(1-e))
     * @param g The g function value
     * @param e The expected score
     * @return The calculated variance
     */
    function calculateV(int256 g, int256 e) internal pure returns (int256) {
        // Calculate g² with proper scaling
        // g is scaled by 1000000, so divide by 1000000 after squaring
        int256 gSquared = (g * g) / 1000000;

        // Calculate e*(1-e) maintaining precision
        // e is scaled by 1000000
        int256 eOneMinusE = (e * (1000000 - e)) / 1000000;

        // Calculate denominator: g²*e*(1-e)
        // Scale up before division to maintain precision
        int256 denominator = (gSquared * eOneMinusE) / 1000000;

        // Ensure we don't divide by zero - use a very small minimum that won't distort calculations
        if (denominator < 1000) {
            denominator = 1000;
        }

        // Calculate final variance: 1/(g²*e*(1-e))
        // Scale result appropriately - we want v ≈ 8935512 for initial values
        int256 result = (1000000 * 1000000) / denominator;

        return result;
    }

    /**
     * @dev Calculate delta for volatility calculation
     * @param v Variance
     * @param g g(phi) value
     * @param outcome Game outcome (1000000 for win, 0 for loss)
     * @param e Expected outcome
     * @return Delta value
     */
    function calculateDelta(
        int256 v,
        int256 g,
        int256 outcome,
        int256 e
    ) internal pure returns (int256) {
        // First calculate (outcome - e) with proper scaling
        int256 scoreDiff = outcome - e;

        // Scale after each multiplication to prevent overflow
        int256 temp = (v * scoreDiff) / 1000000; // First scale down after v * scoreDiff
        int256 delta = (temp * g) / 1000000; // Then scale down after multiplying by g

        return delta;
    }

    /**
     * @dev Calculate new volatility using a simplified algorithm
     * @param volatility Current volatility
     * @param delta Delta value
     * @param phi Current rating deviation
     * @param v Variance
     * @param e Expected outcome
     * @return New volatility
     */
    function calculateNewVolatility(
        int256 volatility,
        int256 delta,
        int256 phi,
        int256 v,
        int256 e
    ) internal pure returns (int256) {
        // Calculate how unexpected the result was
        // e is the expected outcome (between 0 and 1000000)
        // For a win: surprise = 1000000 - e (how unexpected was winning)
        // For a loss: surprise = e (how unexpected was losing)
        int256 surprise = 0;
        if (delta != 0) {
            surprise = delta > 0 ? 1000000 - e : e;
        }

        // Start with current volatility
        int256 newVolatility = volatility;

        // Use variance directly with appropriate scaling
        int256 varianceImpact = v / 100000;

        // Statistically significant surprise (>2σ)
        if (surprise > 680000) {
            // Increase base 6% change based on variance
            newVolatility = (volatility * (1060000 + varianceImpact)) / 1000000;
        }
        // High surprise (>1σ)
        else if (surprise > 500000) {
            // Increase base 3% change based on variance
            newVolatility = (volatility * (1030000 + varianceImpact)) / 1000000;
        }
        // Moderate surprise (within 1σ)
        else if (surprise > 320000) {
            // Increase base 1% change based on variance
            newVolatility = (volatility * (1010000 + varianceImpact)) / 1000000;
        }
        // Expected result
        else {
            // Decrease volatility, moderated by variance
            newVolatility = (volatility * (990000 - varianceImpact)) / 1000000;
        }

        // Additional adjustment based on rating uncertainty (phi)
        if (phi > 250000) {
            int256 volatilityDiff = newVolatility - volatility;
            newVolatility = volatility + (volatilityDiff * 120) / 100;
        }

        // Enforce minimum and maximum bounds
        // Original Glicko-2 Paper Recommendations:
        // The paper suggests volatility should typically be between 0.3 and 0.1
        if (newVolatility > 90000) {
            newVolatility = 90000;
        } else if (newVolatility < 40000) {
            newVolatility = 40000;
        }

        return newVolatility;
    }

    /**
     * @dev Calculate the absolute value of an int256
     * @param x Input value
     * @return Absolute value of x
     */
    function abs(int256 x) internal pure returns (int256) {
        return x >= 0 ? x : -x;
    }

    /**
     * @dev Calculate square root of a number (simplified implementation)
     * @param x Input value
     * @return Square root of x
     */
    function sqrt(int256 x) internal pure returns (int256) {
        if (x <= 0) return 0;

        int256 z = (x + 1) / 2;
        int256 y = x;

        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }

        return y;
    }

    /**
     * @dev Calculate e^x using Taylor series expansion (simplified implementation)
     * @param x Input value (scaled by 1000000)
     * @return e^x (scaled by 1000000)
     */
    function exp(int256 x) internal pure returns (int256) {
        // Limit to reasonable range to avoid overflow
        if (x > 20000000) return 1000000000000; // e^20 is very large
        if (x < -10000000) return 0; // e^-10 is close to 0

        // e^x = 1 + x + x^2/2! + x^3/3! + ... + x^n/n!
        int256 result = 1000000; // 1.0 scaled by 1000000
        int256 term = 1000000; // Start with 1.0 scaled

        for (uint256 i = 1; i <= 32; i++) {
            term = (term * x) / (1000000 * int256(i)); // Scale for precision
            result += term;

            // Break if term becomes too small
            if (abs(term) < 100) break; // 0.0001 scaled
        }

        return result;
    }
}
