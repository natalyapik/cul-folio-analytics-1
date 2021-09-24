/*List of patron requests query*/
/*List of delivery requests by process status query*/
/*Contactless pickup report query*/


/* FIELDS INCLUDED
 * public.circulation_requests table:
 * - request_id
 * - request_date
 * - request_type
 * - request_status
 * - fulfilment_preference
 * folio_reporting.locations_service_points table:
 * - pickup_service_point_display_name
 * - pickup_service_point_name
 * - pickup_library_name
 * folio_reporting.item_ext table:
 * - barcode
 * - material_type_name
 * - permanent_location_name
 * - effective_location_name
 * folio_reporting.holdings_ext table:
 * - call_number
 * - shelving_title
 * folio_reporting.users_groups (derived) table:
 * - user_group
 * - user_last_name
 * - user_first_name
 * - user_middle_name
 * - user_email
 * 
 * FILTERS INCLUDED:
 * - start_date (for request_date)
 * - end_date (for request_date)
 * - items_permanent_location_filter
 */
WITH parameters AS (
    SELECT
        /* Choose a start and end date for the request period */
        '2021-07-01'::date AS start_date,
        '2022-06-30'::date AS end_date,
        /* Fill in a location name, or leave blank for all locations */
        ''::varchar AS items_permanent_location_filter, --Olin, ILR, Africana, etc.
        /* Fill in 1-4 request statuses, or leave all blank for all statuses */
        'Open - Not yet filled'::VARCHAR AS request_status_filter1, --  'Open - Not yet filled', 'Open - Awaiting pickup','Open - In transit', ''Open, Awaiting delivery', 'Closed - Filled', 'Closed - Cancelled', 'Closed - Unfilled', 'Closed - Pickup expired'
        'Open - In transit'::VARCHAR AS request_status_filter2, -- other request status to also include
        ''::VARCHAR AS request_status_filter3, -- other request status to also include
        ''::VARCHAR AS request_status_filter4 -- other request status to also include
),
service_point_libraries AS (
    SELECT
        service_point_id,
        service_point_discovery_display_name,
        service_point_name,
        library_name 
    FROM folio_reporting.locations_service_points
    GROUP BY
        service_point_id,
        service_point_discovery_display_name,
        service_point_name,
        library_name 
)
SELECT
    (SELECT start_date::varchar FROM parameters) || 
        ' to ' || 
        (SELECT end_date::varchar FROM parameters) AS date_range,
    cr.id AS request_id,
    cr.request_date,
    json_extract_path_text(cr.data, 'metadata','updatedDate')::date AS request_updated_date,
    cr.request_type,
    cr.status AS request_status,
    --cr.pickup_service_point_id,
    spl.service_point_discovery_display_name AS pickup_service_point_display_name,
    spl.service_point_name AS pickup_service_point_name,
    spl.library_name AS pickup_library_name,
    cr.fulfilment_preference,
    --ie.item_id,
    he.call_number,
    ie.barcode,
    ie.material_type_name,
    --ie.holdings_record_id,
    ie.permanent_location_name,
    ie.effective_location_name,
    --he.holdings_id,
    he.shelving_title,
    --ug.user_id,
    ug.group_name AS user_group,
    ug.user_last_name,
    ug.user_first_name,
    ug.user_middle_name,
    ug.user_email
FROM
    public.circulation_requests AS cr
LEFT JOIN folio_reporting.item_ext AS ie
	ON cr.item_id = ie.item_id
LEFT JOIN folio_reporting.holdings_ext AS he
	ON ie.holdings_record_id=he.holdings_id
LEFT JOIN folio_reporting.users_groups AS ug
	ON  cr.requester_id = ug.user_id
LEFT JOIN public.inventory_service_points AS isp
	ON cr.pickup_service_point_id = isp.id	
LEFT JOIN service_point_libraries AS spl
	ON cr.pickup_service_point_id = spl.service_point_id
WHERE
    cr.request_date >= (SELECT start_date FROM parameters)
    AND cr.request_date < (SELECT end_date FROM parameters)
    AND (
        ie.permanent_location_name = (SELECT items_permanent_location_filter FROM parameters)
        OR '' = (SELECT items_permanent_location_filter FROM parameters)
    )
    AND (
        cr.status IN ((SELECT request_status_filter1 FROM parameters),
                      (SELECT request_status_filter2 FROM parameters),
                      (SELECT request_status_filter3 FROM parameters),
                      (SELECT request_status_filter4 FROM parameters)
                    )
        OR ('' = (SELECT request_status_filter1 FROM parameters) AND
            '' = (SELECT request_status_filter2 FROM parameters) AND
            '' = (SELECT request_status_filter3 FROM parameters) AND
            '' = (SELECT request_status_filter4 FROM parameters)
            )
    )     
;
