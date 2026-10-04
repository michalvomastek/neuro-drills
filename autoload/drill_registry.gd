## App-wide list of available drills. Adding a drill means adding one entry here.
## The menu groups drills by category in the order of CATEGORY_ORDER.
extends Node

const CATEGORY_ORDER: Array[String] = [
	"CATEGORY_ATTENTION", "CATEGORY_REACTION", "CATEGORY_EXECUTIVE", "CATEGORY_MEMORY",
	"CATEGORY_VISION", "CATEGORY_TIMING", "CATEGORY_MOTOR", "CATEGORY_3D", "CATEGORY_DUAL", "CATEGORY_OTHER",
]

var _definitions: Array[DrillDefinition] = []


func _init() -> void:
	register(DrillDefinition.new(
		&"schulte_table",
		"SCHULTE_TITLE",
		"SCHULTE_DESCRIPTION",
		"res://drills/schulte_table/schulte_table.tscn",
		"CATEGORY_ATTENTION",
	))
	register(DrillDefinition.new(&"reaction_time", "REACTION_TITLE", "REACTION_DESCRIPTION",
		"res://drills/reaction_time/reaction_time.tscn", "CATEGORY_REACTION"))
	register(DrillDefinition.new(&"choice_reaction", "CHOICE_TITLE", "CHOICE_DESCRIPTION",
		"res://drills/choice_reaction/choice_reaction.tscn", "CATEGORY_REACTION"))
	register(DrillDefinition.new(&"go_no_go", "GONOGO_TITLE", "GONOGO_DESCRIPTION",
		"res://drills/go_no_go/go_no_go.tscn", "CATEGORY_REACTION"))
	register(DrillDefinition.new(&"stroop", "STROOP_TITLE", "STROOP_DESCRIPTION",
		"res://drills/stroop/stroop.tscn", "CATEGORY_EXECUTIVE"))
	register(DrillDefinition.new(&"flanker", "FLANKER_TITLE", "FLANKER_DESCRIPTION",
		"res://drills/flanker/flanker.tscn", "CATEGORY_EXECUTIVE"))
	register(DrillDefinition.new(&"n_back", "NBACK_TITLE", "NBACK_DESCRIPTION",
		"res://drills/n_back/n_back.tscn", "CATEGORY_MEMORY"))
	register(DrillDefinition.new(&"corsi_blocks", "CORSI_TITLE", "CORSI_DESCRIPTION",
		"res://drills/corsi_blocks/corsi_blocks.tscn", "CATEGORY_MEMORY"))
	register(DrillDefinition.new(&"digit_span", "DIGIT_TITLE", "DIGIT_DESCRIPTION",
		"res://drills/digit_span/digit_span.tscn", "CATEGORY_MEMORY"))
	register(DrillDefinition.new(&"memory_matrix", "MATRIX_TITLE", "MATRIX_DESCRIPTION",
		"res://drills/memory_matrix/memory_matrix.tscn", "CATEGORY_MEMORY"))
	register(DrillDefinition.new(&"simon", "SIMON_TITLE", "SIMON_DESCRIPTION",
		"res://drills/simon/simon.tscn", "CATEGORY_MEMORY"))
	register(DrillDefinition.new(&"trail_making", "TRAIL_TITLE", "TRAIL_DESCRIPTION",
		"res://drills/trail_making/trail_making.tscn", "CATEGORY_ATTENTION"))
	register(DrillDefinition.new(&"visual_search", "SEARCH_TITLE", "SEARCH_DESCRIPTION",
		"res://drills/visual_search/visual_search.tscn", "CATEGORY_ATTENTION"))
	register(DrillDefinition.new(&"sart", "SART_TITLE", "SART_DESCRIPTION",
		"res://drills/sart/sart.tscn", "CATEGORY_ATTENTION"))
	register(DrillDefinition.new(&"task_switching", "SWITCH_TITLE", "SWITCH_DESCRIPTION",
		"res://drills/task_switching/task_switching.tscn", "CATEGORY_EXECUTIVE"))
	register(DrillDefinition.new(&"rsvp_reading", "RSVP_TITLE", "RSVP_DESCRIPTION",
		"res://drills/rsvp_reading/rsvp_reading.tscn", "CATEGORY_VISION"))
	register(DrillDefinition.new(&"number_pyramid", "PYRAMID_TITLE", "PYRAMID_DESCRIPTION",
		"res://drills/number_pyramid/number_pyramid.tscn", "CATEGORY_VISION"))
	register(DrillDefinition.new(&"flash_number", "FLASH_TITLE", "FLASH_DESCRIPTION",
		"res://drills/flash_number/flash_number.tscn", "CATEGORY_VISION"))
	register(DrillDefinition.new(&"arithmetic", "ARITH_TITLE", "ARITH_DESCRIPTION",
		"res://drills/arithmetic/arithmetic.tscn", "CATEGORY_EXECUTIVE"))
	register(DrillDefinition.new(&"anti_saccade", "ANTI_TITLE", "ANTI_DESCRIPTION",
		"res://drills/anti_saccade/anti_saccade.tscn", "CATEGORY_EXECUTIVE"))
	register(DrillDefinition.new(&"simon_effect", "SIMONEFFECT_TITLE", "SIMONEFFECT_DESCRIPTION",
		"res://drills/simon_effect/simon_effect.tscn", "CATEGORY_EXECUTIVE"))
	register(DrillDefinition.new(&"posner_cueing", "POSNER_TITLE", "POSNER_DESCRIPTION",
		"res://drills/posner_cueing/posner_cueing.tscn", "CATEGORY_ATTENTION"))
	register(DrillDefinition.new(&"peripheral_burst", "PERIPHERAL_TITLE", "PERIPHERAL_DESCRIPTION",
		"res://drills/peripheral_burst/peripheral_burst.tscn", "CATEGORY_VISION"))
	register(DrillDefinition.new(&"visual_masking", "MASKING_TITLE", "MASKING_DESCRIPTION",
		"res://drills/visual_masking/visual_masking.tscn", "CATEGORY_VISION"))
	register(DrillDefinition.new(&"temporal_order", "TOJ_TITLE", "TOJ_DESCRIPTION",
		"res://drills/temporal_order/temporal_order.tscn", "CATEGORY_TIMING"))
	register(DrillDefinition.new(&"object_tracking", "MOT_TITLE", "MOT_DESCRIPTION",
		"res://drills/object_tracking/object_tracking.tscn", "CATEGORY_ATTENTION"))
	register(DrillDefinition.new(&"anticipation", "ANTICIPATION_TITLE", "ANTICIPATION_DESCRIPTION",
		"res://drills/anticipation/anticipation.tscn", "CATEGORY_TIMING"))
	register(DrillDefinition.new(&"compensatory_tracking", "COMPENSATORY_TITLE", "COMPENSATORY_DESCRIPTION",
		"res://drills/compensatory_tracking/compensatory_tracking.tscn", "CATEGORY_MOTOR"))
	register(DrillDefinition.new(&"pursuit_tracking", "PURSUIT_TITLE", "PURSUIT_DESCRIPTION",
		"res://drills/pursuit_tracking/pursuit_tracking.tscn", "CATEGORY_MOTOR"))
	register(DrillDefinition.new(&"dynamic_acuity", "ACUITY_TITLE", "ACUITY_DESCRIPTION",
		"res://drills/dynamic_acuity/dynamic_acuity.tscn", "CATEGORY_VISION"))
	register(DrillDefinition.new(&"rhythm_tapping", "RHYTHM_TITLE", "RHYTHM_DESCRIPTION",
		"res://drills/rhythm_tapping/rhythm_tapping.tscn", "CATEGORY_TIMING"))
	register(DrillDefinition.new(&"mental_rotation", "ROTATION_TITLE", "ROTATION_DESCRIPTION",
		"res://drills/mental_rotation/mental_rotation.tscn", "CATEGORY_EXECUTIVE"))
	register(DrillDefinition.new(&"spotlight_search", "SPOTLIGHT_TITLE", "SPOTLIGHT_DESCRIPTION",
		"res://drills/spotlight_search/spotlight_search.tscn", "CATEGORY_ATTENTION"))
	register(DrillDefinition.new(&"contrast_sensitivity", "CONTRAST_TITLE", "CONTRAST_DESCRIPTION",
		"res://drills/contrast_sensitivity/contrast_sensitivity.tscn", "CATEGORY_VISION"))
	register(DrillDefinition.new(&"okn_stripes", "OKN_TITLE", "OKN_DESCRIPTION",
		"res://drills/okn_stripes/okn_stripes.tscn", "CATEGORY_VISION"))
	register(DrillDefinition.new(&"time_to_contact", "TTC_TITLE", "TTC_DESCRIPTION",
		"res://drills/time_to_contact/time_to_contact.tscn", "CATEGORY_3D"))
	register(DrillDefinition.new(&"brock_string", "BROCK_TITLE", "BROCK_DESCRIPTION",
		"res://drills/brock_string/brock_string.tscn", "CATEGORY_3D"))
	register(DrillDefinition.new(&"rotation_3d", "ROT3D_TITLE", "ROT3D_DESCRIPTION",
		"res://drills/rotation_3d/rotation_3d.tscn", "CATEGORY_3D"))
	register(DrillDefinition.new(&"optic_flow", "LOOMING_TITLE", "LOOMING_DESCRIPTION",
		"res://drills/optic_flow/optic_flow.tscn", "CATEGORY_3D"))
	register(DrillDefinition.new(&"dual_task", "DUAL_TITLE", "DUAL_DESCRIPTION",
		"res://drills/dual_task/dual_task.tscn", "CATEGORY_DUAL"))
	register(DrillDefinition.new(&"divided_attention", "DIVIDED_TITLE", "DIVIDED_DESCRIPTION",
		"res://drills/divided_attention/divided_attention.tscn", "CATEGORY_DUAL"))
	register(DrillDefinition.new(&"peripheral_pattern", "PATTERN_TITLE", "PATTERN_DESCRIPTION",
		"res://drills/peripheral_pattern/peripheral_pattern.tscn", "CATEGORY_VISION"))
	register(DrillDefinition.new(&"peripheral_reading", "READING_TITLE", "READING_DESCRIPTION",
		"res://drills/peripheral_reading/peripheral_reading.tscn", "CATEGORY_VISION"))


func register(definition: DrillDefinition) -> void:
	_definitions.append(definition)


func get_all() -> Array[DrillDefinition]:
	return _definitions.duplicate()


## Drills of one category, in registration order.
func get_by_category(category_key: String) -> Array[DrillDefinition]:
	var out: Array[DrillDefinition] = []
	for definition in _definitions:
		if definition.category_key == category_key:
			out.append(definition)
	return out


## Returns null when no drill has that id.
func find(id: StringName) -> DrillDefinition:
	for definition in _definitions:
		if definition.id == id:
			return definition
	return null
