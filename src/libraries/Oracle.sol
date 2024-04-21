// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library Oracle {
    error Oracle__TargetIsNotAtOrAfterTheOldestObservation();
    uint256 public constant COUNT = 65535;

    event ObservationGrowth(
        uint16 indexed current,
        uint16 indexed next
    );

    /// @notice An observation is a slot that stores a recorded price
    /// @notice A pool contract can store up to 65,535 observations
    /// @notice Each observation is identified by _blockTimestamp()
    struct Observation {
        // the block timestamp of the observation
        uint32 timestamp;
        // tick * delta_time elapsed since the pool was first initialized
        int56 tickAccumulated;
        // the observation is initialized or not.
        bool initialized;
    }


    function initialize(Oracle.Observation[65535] storage self, uint32 time) 
        internal
        returns(uint16 cardinality, uint16 cardinalityNext) 
    {
        self[0] = Observation({
            timestamp: time,
            tickAccumulated: 0,
            initialized: true
        });

        (cardinality, cardinalityNext) = (1, 1);
    }


    /// @dev the #write function could be called just once for each block.
    /// @param self useless
    /// @param _index is the most recently obseravtion index which writtern to the observation index.
    /// @param _cardinality is the number of populated elements in the oracle array.
    /// @param _cardinalityNext is the new length of the oracle array, independent of population.
    /// @param _tick the current tick (and active) at the time of the new observation.
    /// @param _timeStamp is the time of the new observation.
    function write(
        Oracle.Observation[65535] storage self,
        uint16 _index,
        uint16 _cardinality,
        uint16 _cardinalityNext,
        int24 _tick,
        uint32 _timeStamp
    ) internal returns(uint16 newObservationIndex, uint16 newCardinality) {
        Observation memory last = self[_index];
        if (last.timestamp == _timeStamp) {
            (newObservationIndex, newCardinality) = (_index, _cardinality);
        }
        // If the index of obseravations be at the end of the accessable observation array
        // And the cardinalityNext be greater than the ardinality, afterwards cardinality could be increased.
        if (_cardinalityNext > _cardinality && _index == (_cardinalityNext - 1)) {
            newCardinality = _cardinalityNext;
        } else {
            newCardinality = _cardinality;
        }

        newObservationIndex = (_index + 1) % newCardinality;
        self[newObservationIndex] = transform(last, _timeStamp, _tick);
    }


    /// @notice transforming the new observation into the last one.
    /// @param self is the observation that should be transformed.
    /// @param _timeStamp is new timestamp for new observation.
    /// @param _tick is the active-new tick for the new observation.
    /// @return the new observation which has been shifted.
    function transform(
        Observation memory self,
        uint32 _timeStamp,
        int24 _tick
    ) internal returns(Observation memory) {
        uint32 time_delta = _timeStamp - self.timestamp;

        return Observation({
            timestamp: _timeStamp,
            // What we’re calculating here is the accumulated price
            // the current tick gets multiplied by the number of seconds 
            // since the last observation and gets added to the last accumulated price.
            tickAccumulated: self.tickAccumulated + 
                int56(_tick) * int56(uint56(time_delta)),
            initialized: true
        });
    }

    function grow(
        Oracle.Observation[65535] storage self,
        uint16 _currentCardinality,
        uint16 _newProposedCardinality
    ) internal returns(uint16) {
        if (_currentCardinality < _newProposedCardinality) return _currentCardinality;

        for (uint16 i = _currentCardinality; i < _newProposedCardinality; i++) {
            self[i].timestamp = 1; // there obseravation can't be used because the initialized parameter is false.
        }

        emit ObservationGrowth(_currentCardinality, _newProposedCardinality);
    }


    /// @notice Returns the accumulator values as of each time seconds ago from the given time in the array of `secondsAgos`
    /// @param self is the oracle array.
    /// @param _time is the current timestamp
    /// @param _timePoints Each amount of time to look back, in seconds, at which point to return an observation
    ///        the list of time points that we want to get prices at.
    /// @param _tick is the current tick
    /// @param _cardinality the number of observation block.
    /// @param _index is the most recent observation index.
    /// @return tickCumulatives The tick * time elapsed since the pool was first initialized, as of each `secondsAgo`
    function observe(
        Observation[65535] storage self,
        uint32 _time,
        int24 _tick,
        uint16 _cardinality,
        uint16 _index,
        uint32[] memory _timePoints
    ) internal returns(int56[] memory tickCumulatives) {
        tickCumulatives = new int56[](_timePoints.length);

        for (uint256 i = 0; i < _timePoints.length; i++) {
            tickCumulatives[i] = observeSingle(
                self, _time, _timePoints[i], _tick, _index, _cardinality);
        }
    }


    /// @dev Reverts if an observation at or before the desired observation timestamp does not exist.
    /// 0 may be passed as `secondsAgo' to return the current cumulative values.
    /// If called with a timestamp falling between two observations, returns the counterfactual accumulator values
    /// at exactly the timestamp between the two observations.
    /// @dev If an older time point is requested, we need to make several checks before switching to the binary search algorithm:
    ///     if the requested time point is the last observation, we can return the accumulated price at the latest observation;
    ///     if the requested time point is after the last observation, we can call transform to find the accumulated price at this point, knowing the last observed price and the current price;
    ///     `if the requested time point is before the last observation, we have to use the binary search.`
    /// @param self The stored oracle array
    /// @param _time The current block timestamp
    /// @param _secondsAgo The amount of time to look back, in seconds, at which point to return an observation
    /// @param _tick The current tick
    /// @param _index The index of the observation that was most recently written to the observations array
    /// @param _cardinality The number of populated elements in the oracle array
    /// @return tickCumulative The tick * time elapsed since the pool was first initialized, as of `secondsAgo`
    function observeSingle(
        Observation[65535] storage self,
        uint32 _time,
        uint32 _secondsAgo,
        int24 _tick,
        uint16 _index,
        uint16 _cardinality
    ) internal returns (int56 tickCumulative) {
        // If it wasn’t recorded in the current block, transform it to consider the current block and the current tick.
        if (_secondsAgo == 0) {
            Observation memory last = self[_index];
            if (last.timestamp == 0) {
                last = transform(last, _time, _tick);
            }
            return last.tickAccumulated;
        }

        uint32 target = _time - _secondsAgo;

        (Observation memory ObservationAtOrBelow, Observation memory ObservationAtOrAbove) = getObservationBouderies(
            self, _time, target, _tick, _index, _cardinality);

        // when we are in the left side
        if (target == ObservationAtOrBelow.timestamp) return ObservationAtOrBelow.tickAccumulated;
        // when we are in the right side
        else if (target == ObservationAtOrAbove.timestamp) return ObservationAtOrAbove.tickAccumulated;
        // when are in the middle
        else {
            uint56 bounderiesTimeDelta = uint56(ObservationAtOrAbove.timestamp - ObservationAtOrBelow.timestamp);
            uint56 targetTimeDelta = uint56(_time - ObservationAtOrBelow.timestamp);
            // calculating tick cumulative
            return ObservationAtOrBelow.tickAccumulated +
                ((ObservationAtOrBelow.tickAccumulated - ObservationAtOrAbove.tickAccumulated) /
                    int56(bounderiesTimeDelta)
                ) * int56(targetTimeDelta);
        }
    }

    
    /// @notice Returns the range between two observations in which the requested time point is located.
    /// @param _time is the current timestamp
    /// @param _pricePointTarget is the target price point timestamp which has requested.
    /// @param _index is the current most recent observation's index.
    /// @param _cardinality is the available observation range known as cardinality.
    /// @return ObservationAtOrBelow of the target price point timestamp.
    /// @return ObservationAtOrAbove of the target price point timestamp.
    /// @dev if the requested time point is before the last observation, we have to use the binary search (not anywhere).
    function observationBinarySearch(
        Observation[65535] storage self,
        uint32 _time,
        uint32 _pricePointTarget,
        uint16 _index,
        uint16 _cardinality
    ) internal view returns(Observation memory ObservationAtOrBelow, Observation memory ObservationAtOrAbove) {
        uint256 left = (_index + 1) % _cardinality; // oldest obs
        uint256 right = left + _cardinality - 1;
        uint256 i;

        while (true) {
            i = (left + right) / 2;
            ObservationAtOrBelow = self[i % _cardinality];
            if (!ObservationAtOrBelow.initialized) {
                left = i + 1;
                continue;
            }

            ObservationAtOrAbove = self[(i + 1) % _cardinality];
            
            bool targetedOrAfter = lte(_time, ObservationAtOrBelow.timestamp, _pricePointTarget);
            if (targetedOrAfter && lte(_time, _pricePointTarget, ObservationAtOrAbove.timestamp)) break;

            if(!targetedOrAfter) right = i - 1;
            else left = i + 1;
        }
    }


    /// @notice Fetches the observations beforeOrAt and atOrAfter a given target, i.e. where [beforeOrAt, atOrAfter] is satisfied
    /// @dev Used by observeSingle() to compute the counterfactual accumulator values as of a given block timestamp.
    /// @param self is the stored oracle observation
    /// @param _time is the current timestamp
    /// @param _pricePointTarget is the target observation timestamp which the reserved observation should be for
    /// @param _tick is the current tick
    /// @param _index is the most recent observation index.
    /// @param _cardinality is the observation array cardinality.
    /// @return ObservationAtOrBelow the observation that occurred at or before based on the given timestamp.
    /// @return ObservationAtOrAbove the observation that occurred at to after based on the given timestamp.
    function getObservationBouderies(
        Observation[65535] storage self,
        uint32 _time,
        uint32 _pricePointTarget,
        int24 _tick,
        uint16 _index,
        uint16 _cardinality
    ) private returns(Observation memory ObservationAtOrBelow, Observation memory ObservationAtOrAbove) {
        // optimistically set before to the newest observation
        ObservationAtOrBelow = self[_index];

        // if the target is chronologically at or after the newest observation, we can early return
        if (lte(_time, ObservationAtOrBelow.timestamp, _pricePointTarget)) {
            if (ObservationAtOrBelow.timestamp == _pricePointTarget) {
                // if newest observation equals target, we're in the same block, so we can ignore atOrAfter
                return (ObservationAtOrBelow, ObservationAtOrAbove);
            } else {
                // otherwise, we need to transform
                return (ObservationAtOrBelow, transform(ObservationAtOrBelow, _pricePointTarget, _tick));
            }
        }

        // now, set before to the oldest observation
        ObservationAtOrBelow = self[(_index + 1) % _cardinality];
        if (!ObservationAtOrBelow.initialized) ObservationAtOrBelow = self[0];

        // ensure that the target is chronologically at or after the oldest observation
        if(!lte(_time, ObservationAtOrBelow.timestamp, _pricePointTarget)) revert Oracle__TargetIsNotAtOrAfterTheOldestObservation();

        // if we've reached this point, we have to binary search
        return observationBinarySearch(self, _time, _pricePointTarget, _index, _cardinality);
    }


    /// @notice comparator for 32-bit timestamps
    /// @dev a and b _must_ be chronologically before or equal to time
    /// @param time A timestamp truncated to 32 bits
    /// @param a A comparison timestamp from which to determine the relative position of `time`
    /// @param b From which to determine the relative position of `time`
    /// @return bool Whether `a` is chronologically <= `b`
    function lte(
        uint32 time,
        uint32 a,
        uint32 b
    ) private pure returns (bool) {
        // if there hasn't been overflow, no need to adjust
        if (a <= time && b <= time) return a <= b;

        uint256 aAdjusted = a > time ? a : a + 2**32;
        uint256 bAdjusted = b > time ? b : b + 2**32;

        return aAdjusted <= bAdjusted;
    }
}