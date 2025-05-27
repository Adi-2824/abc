// Controllers/ReservationsController.cs
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;
using AirTicketReservation.DTOs;
using AirTicketReservation.Services;

namespace AirTicketReservation.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class ReservationsController : ControllerBase
    {
        private readonly IReservationService _reservationService;
        private readonly IReservationHistoryService _reservationHistoryService;

        public ReservationsController(
            IReservationService reservationService,
            IReservationHistoryService reservationHistoryService)
        {
            _reservationService = reservationService;
            _reservationHistoryService = reservationHistoryService;
        }

        /// <summary>
        /// Create a new reservation
        /// </summary>
        [HttpPost]
        public async Task<ActionResult<ReservationDTO>> CreateReservation([FromBody] CreateReservationDTO createReservationDto)
        {
            try
            {
                var userId = GetCurrentUserId();
                var reservation = await _reservationService.CreateReservationAsync(userId, createReservationDto);
                return CreatedAtAction(nameof(GetReservation), new { id = reservation.Id }, reservation);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        /// <summary>
        /// Get all reservations of the current user
        /// </summary>
        [HttpGet]
        public async Task<ActionResult<List<ReservationDTO>>> GetUserReservations()
        {
            var userId = GetCurrentUserId();
            var reservations = await _reservationService.GetUserReservationsAsync(userId);
            return Ok(reservations);
        }

        /// <summary>
        /// Get reservation details by ID
        /// </summary>
        [HttpGet("{id}")]
        public async Task<ActionResult<ReservationDTO>> GetReservation(int id)
        {
            var userId = GetCurrentUserId();
            var reservation = await _reservationService.GetReservationByIdAsync(id, userId);
            if (reservation == null)
                return NotFound(new { message = "Reservation not found" });

            return Ok(reservation);
        }

        /// <summary>
        /// Cancel a reservation
        /// </summary>
        [HttpPut("{id}/cancel")]
        public async Task<ActionResult> CancelReservation(int id)
        {
            var userId = GetCurrentUserId();
            var result = await _reservationService.CancelReservationAsync(id, userId);
            if (!result)
                return NotFound(new { message = "Reservation not found or already cancelled" });

            return Ok(new { message = "Reservation cancelled successfully" });
        }

        /// <summary>
        /// Calculate total reservation amount
        /// </summary>
        [HttpPost("calculate-amount")]
        public async Task<ActionResult<decimal>> CalculateTotalAmount([FromBody] CreateReservationDTO createReservationDto)
        {
            try
            {
                var amount = await _reservationService.CalculateTotalAmountAsync(createReservationDto.FlightId, createReservationDto.Passengers);
                return Ok(new { totalAmount = amount });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        /// <summary>
        /// Get paginated reservation history with filters
        /// </summary>
        [HttpGet("history")]
        public async Task<ActionResult<PaginatedReservationHistoryDTO>> GetReservationHistory([FromQuery] ReservationHistoryFilterDTO filter)
        {
            var userId = GetCurrentUserId();
            var result = await _reservationHistoryService.GetReservationHistoryAsync(userId, filter);
            return Ok(result);
        }

        /// <summary>
        /// Get upcoming journeys
        /// </summary>
        [HttpGet("history/upcoming")]
        public async Task<ActionResult<List<ReservationHistoryDTO>>> GetUpcomingJourneys()
        {
            var userId = GetCurrentUserId();
            var upcoming = await _reservationHistoryService.GetUpcomingJourneysAsync(userId);
            return Ok(upcoming);
        }

        /// <summary>
        /// Get past journeys
        /// </summary>
        [HttpGet("history/past")]
        public async Task<ActionResult<List<ReservationHistoryDTO>>> GetPastJourneys([FromQuery] int limit = 10)
        {
            var userId = GetCurrentUserId();
            var past = await _reservationHistoryService.GetPastJourneysAsync(userId, limit);
            return Ok(past);
        }

        /// <summary>
        /// Get reservation history details by ID
        /// </summary>
        [HttpGet("history/{id}")]
        public async Task<ActionResult<ReservationHistoryDTO>> GetReservationHistoryById(int id)
        {
            var userId = GetCurrentUserId();
            var history = await _reservationHistoryService.GetReservationHistoryByIdAsync(id, userId);
            if (history == null)
                return NotFound(new { message = "Reservation not found" });

            return Ok(history);
        }

        /// <summary>
        /// Get reservation summary and statistics
        /// </summary>
        [HttpGet("history/summary")]
        public async Task<ActionResult<ReservationHistorySummaryDTO>> GetReservationSummary()
        {
            var userId = GetCurrentUserId();
            var summary = await _reservationHistoryService.GetReservationSummaryAsync(userId);
            return Ok(summary);
        }

        /// <summary>
        /// Get recent bookings
        /// </summary>
        [HttpGet("history/recent")]
        public async Task<ActionResult<List<ReservationHistoryDTO>>> GetRecentBookings([FromQuery] int limit = 5)
        {
            var userId = GetCurrentUserId();
            var recent = await _reservationHistoryService.GetRecentBookingsAsync(userId, limit);
            return Ok(recent);
        }

        /// <summary>
        /// Check if a reservation can be cancelled
        /// </summary>
        [HttpGet("{id}/can-cancel")]
        public async Task<ActionResult<bool>> CanCancelReservation(int id)
        {
            var userId = GetCurrentUserId();
            var canCancel = await _reservationHistoryService.CanCancelReservationAsync(id, userId);
            return Ok(new { canCancel });
        }

        /// <summary>
        /// Check if a reservation can be modified
        /// </summary>
        [HttpGet("{id}/can-modify")]
        public async Task<ActionResult<bool>> CanModifyReservation(int id)
        {
            var userId = GetCurrentUserId();
            var canModify = await _reservationHistoryService.CanModifyReservationAsync(id, userId);
            return Ok(new { canModify });
        }

        private int GetCurrentUserId()
        {
            var claim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (int.TryParse(claim, out var userId))
                return userId;

            throw new UnauthorizedAccessException("Invalid user ID");
        }
    }
}
