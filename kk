// Enhanced DTOs for Reservation History
// DTOs/ReservationHistoryDTOs.cs
using AirTicketReservation.Models;
using System.ComponentModel.DataAnnotations;

namespace AirTicketReservation.DTOs
{
    public class ReservationHistoryDTO
    {
        public int Id { get; set; }
        public string BookingReference { get; set; }
        public FlightHistoryDTO Flight { get; set; }
        public DateTime BookingDate { get; set; }
        public ReservationStatus Status { get; set; }
        public decimal TotalAmount { get; set; }
        public List<PassengerHistoryDTO> Passengers { get; set; }
        public PaymentHistoryDTO Payment { get; set; }
        public JourneyType JourneyType { get; set; } // Past, Upcoming, Current
        public int DaysUntilDeparture { get; set; }
        public bool CanCancel { get; set; }
        public bool CanModify { get; set; }
    }

    public class FlightHistoryDTO
    {
        public int Id { get; set; }
        public string FlightNumber { get; set; }
        public string Airline { get; set; }
        public string Origin { get; set; }
        public string Destination { get; set; }
        public DateTime DepartureDateTime { get; set; }
        public DateTime ArrivalDateTime { get; set; }
        public decimal EconomyPrice { get; set; }
        public decimal BusinessPrice { get; set; }
        public string Aircraft { get; set; }
        public FlightStatus Status { get; set; }
        public string Duration => CalculateFlightDuration();
        
        private string CalculateFlightDuration()
        {
            var duration = ArrivalDateTime - DepartureDateTime;
            return $"{duration.Hours}h {duration.Minutes}m";
        }
    }

    public class PassengerHistoryDTO
    {
        public int Id { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string FullName => $"{FirstName} {LastName}";
        public int Age { get; set; }
        public Gender Gender { get; set; }
        public SeatClass SeatClass { get; set; }
        public string SeatNumber { get; set; }
        public string TicketNumber { get; set; }
    }

    public class PaymentHistoryDTO
    {
        public int Id { get; set; }
        public decimal Amount { get; set; }
        public PaymentMethod PaymentMethod { get; set; }
        public PaymentStatus Status { get; set; }
        public DateTime PaymentDate { get; set; }
        public string TransactionId { get; set; }
        public string PaymentMethodDisplay => GetPaymentMethodDisplay();
        
        private string GetPaymentMethodDisplay()
        {
            return PaymentMethod switch
            {
                PaymentMethod.CreditCard => "Credit Card",
                PaymentMethod.DebitCard => "Debit Card",
                PaymentMethod.PayPal => "PayPal",
                PaymentMethod.BankTransfer => "Bank Transfer",
                _ => PaymentMethod.ToString()
            };
        }
    }

    public class ReservationHistoryFilterDTO
    {
        public JourneyType? JourneyType { get; set; }
        public ReservationStatus? Status { get; set; }
        public DateTime? FromDate { get; set; }
        public DateTime? ToDate { get; set; }
        public string Airline { get; set; }
        public string Origin { get; set; }
        public string Destination { get; set; }
        public int Page { get; set; } = 1;
        public int PageSize { get; set; } = 10;
        public string SortBy { get; set; } = "BookingDate"; // BookingDate, DepartureDate, Amount
        public bool SortDescending { get; set; } = true;
    }

    public class ReservationHistorySummaryDTO
    {
        public int TotalBookings { get; set; }
        public int UpcomingJourneys { get; set; }
        public int CompletedJourneys { get; set; }
        public int CancelledBookings { get; set; }
        public decimal TotalAmountSpent { get; set; }
        public decimal AmountThisYear { get; set; }
        public string MostFrequentDestination { get; set; }
        public string PreferredAirline { get; set; }
        public List<MonthlyBookingStatDTO> MonthlyStats { get; set; }
    }

    public class MonthlyBookingStatDTO
    {
        public int Year { get; set; }
        public int Month { get; set; }
        public string MonthName { get; set; }
        public int BookingCount { get; set; }
        public decimal TotalAmount { get; set; }
    }

    public class PaginatedReservationHistoryDTO
    {
        public List<ReservationHistoryDTO> Reservations { get; set; }
        public int TotalCount { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
        public int TotalPages { get; set; }
        public bool HasNextPage { get; set; }
        public bool HasPreviousPage { get; set; }
    }

    public enum JourneyType
    {
        Past,
        Upcoming,
        Current
    }
}

// Enhanced Service Interface
// Services/IReservationHistoryService.cs
using AirTicketReservation.DTOs;

namespace AirTicketReservation.Services
{
    public interface IReservationHistoryService
    {
        Task<PaginatedReservationHistoryDTO> GetReservationHistoryAsync(int userId, ReservationHistoryFilterDTO filter);
        Task<List<ReservationHistoryDTO>> GetUpcomingJourneysAsync(int userId);
        Task<List<ReservationHistoryDTO>> GetPastJourneysAsync(int userId, int limit = 10);
        Task<ReservationHistoryDTO> GetReservationHistoryByIdAsync(int reservationId, int userId);
        Task<ReservationHistorySummaryDTO> GetReservationSummaryAsync(int userId);
        Task<List<ReservationHistoryDTO>> GetRecentBookingsAsync(int userId, int limit = 5);
        Task<bool> CanCancelReservationAsync(int reservationId, int userId);
        Task<bool> CanModifyReservationAsync(int reservationId, int userId);
    }
}

// Enhanced Service Implementation
// Services/ReservationHistoryService.cs
using Microsoft.EntityFrameworkCore;
using AirTicketReservation.Data;
using AirTicketReservation.DTOs;
using AirTicketReservation.Models;

namespace AirTicketReservation.Services
{
    public class ReservationHistoryService : IReservationHistoryService
    {
        private readonly ApplicationDbContext _context;
        
        public ReservationHistoryService(ApplicationDbContext context)
        {
            _context = context;
        }
        
        public async Task<PaginatedReservationHistoryDTO> GetReservationHistoryAsync(int userId, ReservationHistoryFilterDTO filter)
        {
            var query = _context.Reservations
                .Include(r => r.Flight)
                .Include(r => r.Passengers)
                .Include(r => r.Payment)
                .Where(r => r.UserId == userId);
            
            // Apply filters
            if (filter.JourneyType.HasValue)
            {
                var now = DateTime.UtcNow;
                query = filter.JourneyType.Value switch
                {
                    JourneyType.Past => query.Where(r => r.Flight.ArrivalDateTime < now),
                    JourneyType.Upcoming => query.Where(r => r.Flight.DepartureDateTime > now),
                    JourneyType.Current => query.Where(r => r.Flight.DepartureDateTime <= now && r.Flight.ArrivalDateTime >= now),
                    _ => query
                };
            }
            
            if (filter.Status.HasValue)
            {
                query = query.Where(r => r.Status == filter.Status.Value);
            }
            
            if (filter.FromDate.HasValue)
            {
                query = query.Where(r => r.BookingDate >= filter.FromDate.Value);
            }
            
            if (filter.ToDate.HasValue)
            {
                query = query.Where(r => r.BookingDate <= filter.ToDate.Value);
            }
            
            if (!string.IsNullOrEmpty(filter.Airline))
            {
                query = query.Where(r => r.Flight.Airline.Contains(filter.Airline));
            }
            
            if (!string.IsNullOrEmpty(filter.Origin))
            {
                query = query.Where(r => r.Flight.Origin.Contains(filter.Origin));
            }
            
            if (!string.IsNullOrEmpty(filter.Destination))
            {
                query = query.Where(r => r.Flight.Destination.Contains(filter.Destination));
            }
            
            // Apply sorting
            query = filter.SortBy?.ToLower() switch
            {
                "departuredate" => filter.SortDescending 
                    ? query.OrderByDescending(r => r.Flight.DepartureDateTime)
                    : query.OrderBy(r => r.Flight.DepartureDateTime),
                "amount" => filter.SortDescending 
                    ? query.OrderByDescending(r => r.TotalAmount)
                    : query.OrderBy(r => r.TotalAmount),
                _ => filter.SortDescending 
                    ? query.OrderByDescending(r => r.BookingDate)
                    : query.OrderBy(r => r.BookingDate)
            };
            
            var totalCount = await query.CountAsync();
            var totalPages = (int)Math.Ceiling((double)totalCount / filter.PageSize);
            
            var reservations = await query
                .Skip((filter.Page - 1) * filter.PageSize)
                .Take(filter.PageSize)
                .ToListAsync();
            
            var reservationDTOs = reservations.Select(MapToReservationHistoryDTO).ToList();
            
            return new PaginatedReservationHistoryDTO
            {
                Reservations = reservationDTOs,
                TotalCount = totalCount,
                Page = filter.Page,
                PageSize = filter.PageSize,
                TotalPages = totalPages,
                HasNextPage = filter.Page < totalPages,
                HasPreviousPage = filter.Page > 1
            };
        }
        
        public async Task<List<ReservationHistoryDTO>> GetUpcomingJourneysAsync(int userId)
        {
            var now = DateTime.UtcNow;
            
            var reservations = await _context.Reservations
                .Include(r => r.Flight)
                .Include(r => r.Passengers)
                .Include(r => r.Payment)
                .Where(r => r.UserId == userId && 
                           r.Flight.DepartureDateTime > now &&
                           r.Status == ReservationStatus.Confirmed)
                .OrderBy(r => r.Flight.DepartureDateTime)
                .ToListAsync();
            
            return reservations.Select(MapToReservationHistoryDTO).ToList();
        }
        
        public async Task<List<ReservationHistoryDTO>> GetPastJourneysAsync(int userId, int limit = 10)
        {
            var now = DateTime.UtcNow;
            
            var reservations = await _context.Reservations
                .Include(r => r.Flight)
                .Include(r => r.Passengers)
                .Include(r => r.Payment)
                .Where(r => r.UserId == userId && r.Flight.ArrivalDateTime < now)
                .OrderByDescending(r => r.Flight.DepartureDateTime)
                .Take(limit)
                .ToListAsync();
            
            return reservations.Select(MapToReservationHistoryDTO).ToList();
        }
        
        public async Task<ReservationHistoryDTO> GetReservationHistoryByIdAsync(int reservationId, int userId)
        {
            var reservation = await _context.Reservations
                .Include(r => r.Flight)
                .Include(r => r.Passengers)
                .Include(r => r.Payment)
                .FirstOrDefaultAsync(r => r.Id == reservationId && r.UserId == userId);
            
            return reservation != null ? MapToReservationHistoryDTO(reservation) : null;
        }
        
        public async Task<ReservationHistorySummaryDTO> GetReservationSummaryAsync(int userId)
        {
            var now = DateTime.UtcNow;
            var currentYear = now.Year;
            
            var reservations = await _context.Reservations
                .Include(r => r.Flight)
                .Where(r => r.UserId == userId)
                .ToListAsync();
            
            var totalBookings = reservations.Count;
            var upcomingJourneys = reservations.Count(r => r.Flight.DepartureDateTime > now && r.Status == ReservationStatus.Confirmed);
            var completedJourneys = reservations.Count(r => r.Flight.ArrivalDateTime < now && r.Status == ReservationStatus.Confirmed);
            var cancelledBookings = reservations.Count(r => r.Status == ReservationStatus.Cancelled);
            var totalAmountSpent = reservations.Where(r => r.Status == ReservationStatus.Confirmed).Sum(r => r.TotalAmount);
            var amountThisYear = reservations.Where(r => r.BookingDate.Year == currentYear && r.Status == ReservationStatus.Confirmed).Sum(r => r.TotalAmount);
            
            var mostFrequentDestination = reservations
                .Where(r => r.Status == ReservationStatus.Confirmed)
                .GroupBy(r => r.Flight.Destination)
                .OrderByDescending(g => g.Count())
                .FirstOrDefault()?.Key ?? "N/A";
            
            var preferredAirline = reservations
                .Where(r => r.Status == ReservationStatus.Confirmed)
                .GroupBy(r => r.Flight.Airline)
                .OrderByDescending(g => g.Count())
                .FirstOrDefault()?.Key ?? "N/A";
            
            var monthlyStats = reservations
                .Where(r => r.Status == ReservationStatus.Confirmed)
                .GroupBy(r => new { r.BookingDate.Year, r.BookingDate.Month })
                .Select(g => new MonthlyBookingStatDTO
                {
                    Year = g.Key.Year,
                    Month = g.Key.Month,
                    MonthName = new DateTime(g.Key.Year, g.Key.Month, 1).ToString("MMMM yyyy"),
                    BookingCount = g.Count(),
                    TotalAmount = g.Sum(r => r.TotalAmount)
                })
                .OrderByDescending(s => s.Year)
                .ThenByDescending(s => s.Month)
                .Take(12)
                .ToList();
            
            return new ReservationHistorySummaryDTO
            {
                TotalBookings = totalBookings,
                UpcomingJourneys = upcomingJourneys,
                CompletedJourneys = completedJourneys,
                CancelledBookings = cancelledBookings,
                TotalAmountSpent = totalAmountSpent,
                AmountThisYear = amountThisYear,
                MostFrequentDestination = mostFrequentDestination,
                PreferredAirline = preferredAirline,
                MonthlyStats = monthlyStats
            };
        }
        
        public async Task<List<ReservationHistoryDTO>> GetRecentBookingsAsync(int userId, int limit = 5)
        {
            var reservations = await _context.Reservations
                .Include(r => r.Flight)
                .Include(r => r.Passengers)
                .Include(r => r.Payment)
                .Where(r => r.UserId == userId)
                .OrderByDescending(r => r.BookingDate)
                .Take(limit)
                .ToListAsync();
            
            return reservations.Select(MapToReservationHistoryDTO).ToList();
        }
        
        public async Task<bool> CanCancelReservationAsync(int reservationId, int userId)
        {
            var reservation = await _context.Reservations
                .Include(r => r.Flight)
                .FirstOrDefaultAsync(r => r.Id == reservationId && r.UserId == userId);
            
            if (reservation == null || reservation.Status != ReservationStatus.Confirmed)
                return false;
            
            // Can cancel if departure is more than 24 hours away
            var hoursUntilDeparture = (reservation.Flight.DepartureDateTime - DateTime.UtcNow).TotalHours;
            return hoursUntilDeparture > 24;
        }
        
        public async Task<bool> CanModifyReservationAsync(int reservationId, int userId)
        {
            var reservation = await _context.Reservations
                .Include(r => r.Flight)
                .FirstOrDefaultAsync(r => r.Id == reservationId && r.UserId == userId);
            
            if (reservation == null || reservation.Status != ReservationStatus.Confirmed)
                return false;
            
            // Can modify if departure is more than 48 hours away
            var hoursUntilDeparture = (reservation.Flight.DepartureDateTime - DateTime.UtcNow).TotalHours;
            return hoursUntilDeparture > 48;
        }
        
        private ReservationHistoryDTO MapToReservationHistoryDTO(Reservation reservation)
        {
            var now = DateTime.UtcNow;
            var departureTime = reservation.Flight.DepartureDateTime;
            var arrivalTime = reservation.Flight.ArrivalDateTime;
            
            var journeyType = JourneyType.Past;
            if (departureTime > now)
                journeyType = JourneyType.Upcoming;
            else if (departureTime <= now && arrivalTime >= now)
                journeyType = JourneyType.Current;
            
            var daysUntilDeparture = (int)(departureTime - now).TotalDays;
            
            return new ReservationHistoryDTO
            {
                Id = reservation.Id,
                BookingReference = reservation.BookingReference,
                BookingDate = reservation.BookingDate,
                Status = reservation.Status,
                TotalAmount = reservation.TotalAmount,
                JourneyType = journeyType,
                DaysUntilDeparture = daysUntilDeparture,
                CanCancel = reservation.Status == ReservationStatus.Confirmed && (departureTime - now).TotalHours > 24,
                CanModify = reservation.Status == ReservationStatus.Confirmed && (departureTime - now).TotalHours > 48,
                Flight = new FlightHistoryDTO
                {
                    Id = reservation.Flight.Id,
                    FlightNumber = reservation.Flight.FlightNumber,
                    Airline = reservation.Flight.Airline,
                    Origin = reservation.Flight.Origin,
                    Destination = reservation.Flight.Destination,
                    DepartureDateTime = reservation.Flight.DepartureDateTime,
                    ArrivalDateTime = reservation.Flight.ArrivalDateTime,
                    EconomyPrice = reservation.Flight.EconomyPrice,
                    BusinessPrice = reservation.Flight.BusinessPrice,
                    Aircraft = reservation.Flight.Aircraft,
                    Status = reservation.Flight.Status
                },
                Passengers = reservation.Passengers.Select(p => new PassengerHistoryDTO
                {
                    Id = p.Id,
                    FirstName = p.FirstName,
                    LastName = p.LastName,
                    Age = p.Age,
                    Gender = p.Gender,
                    SeatClass = p.SeatClass,
                    SeatNumber = p.SeatNumber ?? "Not Assigned",
                    TicketNumber = $"TKT{reservation.Id:D6}{p.Id:D3}"
                }).ToList(),
                Payment = reservation.Payment != null ? new PaymentHistoryDTO
                {
                    Id = reservation.Payment.Id,
                    Amount = reservation.Payment.Amount,
                    PaymentMethod = reservation.Payment.PaymentMethod,
                    Status = reservation.Payment.Status,
                    PaymentDate = reservation.Payment.PaymentDate,
                    TransactionId = reservation.Payment.TransactionId
                } : null
            };
        }
    }
}

// Enhanced Controller
// Controllers/ReservationHistoryController.cs
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
    public class ReservationHistoryController : ControllerBase
    {
        private readonly IReservationHistoryService _reservationHistoryService;
        
        public ReservationHistoryController(IReservationHistoryService reservationHistoryService)
        {
            _reservationHistoryService = reservationHistoryService;
        }
        
        /// <summary>
        /// Get paginated reservation history with filters
        /// </summary>
        [HttpGet]
        public async Task<ActionResult<PaginatedReservationHistoryDTO>> GetReservationHistory([FromQuery] ReservationHistoryFilterDTO filter)
        {
            var userId = GetCurrentUserId();
            var result = await _reservationHistoryService.GetReservationHistoryAsync(userId, filter);
            return Ok(result);
        }
        
        /// <summary>
        /// Get upcoming journeys for the user
        /// </summary>
        [HttpGet("upcoming")]
        public async Task<ActionResult<List<ReservationHistoryDTO>>> GetUpcomingJourneys()
        {
            var userId = GetCurrentUserId();
            var upcomingJourneys = await _reservationHistoryService.GetUpcomingJourneysAsync(userId);
            return Ok(upcomingJourneys);
        }
        
        /// <summary>
        /// Get past journeys for the user
        /// </summary>
        [HttpGet("past")]
        public async Task<ActionResult<List<ReservationHistoryDTO>>> GetPastJourneys([FromQuery] int limit = 10)
        {
            var userId = GetCurrentUserId();
            var pastJourneys = await _reservationHistoryService.GetPastJourneysAsync(userId, limit);
            return Ok(pastJourneys);
        }
        
        /// <summary>
        /// Get detailed information about a specific reservation
        /// </summary>
        [HttpGet("{id}")]
        public async Task<ActionResult<ReservationHistoryDTO>> GetReservationHistory(int id)
        {
            var userId = GetCurrentUserId();
            var reservation = await _reservationHistoryService.GetReservationHistoryByIdAsync(id, userId);
            
            if (reservation == null)
                return NotFound(new { message = "Reservation not found" });
            
            return Ok(reservation);
        }
        
        /// <summary>
        /// Get reservation summary and statistics
        /// </summary>
        [HttpGet("summary")]
        public async Task<ActionResult<ReservationHistorySummaryDTO>> GetReservationSummary()
        {
            var userId = GetCurrentUserId();
            var summary = await _reservationHistoryService.GetReservationSummaryAsync(userId);
            return Ok(summary);
        }
        
        /// <summary>
        /// Get recent bookings
        /// </summary>
        [HttpGet("recent")]
        public async Task<ActionResult<List<ReservationHistoryDTO>>> GetRecentBookings([FromQuery] int limit = 5)
        {
            var userId = GetCurrentUserId();
            var recentBookings = await _reservationHistoryService.GetRecentBookingsAsync(userId, limit);
            return Ok(recentBookings);
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
            return int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "0");
        }
    }
}

// Additional Models for Enhanced Functionality
// Models/ReservationAudit.cs (Optional - for tracking changes)
using System.ComponentModel.DataAnnotations;

namespace AirTicketReservation.Models
{
    public class ReservationAudit
    {
        public int Id { get; set; }
        
        public int ReservationId { get; set; }
        public Reservation Reservation { get; set; }
        
        public string Action { get; set; } // Created, Modified, Cancelled, etc.
        
        public string Details { get; set; } // JSON of what changed
        
        public DateTime ActionDate { get; set; } = DateTime.UtcNow;
        
        public int UserId { get; set; }
        
        public string IpAddress { get; set; }
        
        public string UserAgent { get; set; }
    }
}

// Update Program.cs to register the new service
// Add this line in Program.cs with other service registrations:
// builder.Services.AddScoped<IReservationHistoryService, ReservationHistoryService>();
